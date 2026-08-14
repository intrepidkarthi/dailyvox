import Foundation
import SwiftUI
import Photos
import Vision
import MediaPlayer

// v1.5.5 Ambient Signals — capture side. Both sources run entirely on-device
// and emit only derived labels into the review queue. Off by default; each
// source is a separate opt-in with its own system permission.

@MainActor
final class AmbientSignalManager: ObservableObject {
    static let shared = AmbientSignalManager()

    // Off by default (roadmap requirement). Per-source opt-in.
    @AppStorage("ambientPhotoSignalsEnabled") var photoSignalsEnabled = false
    @AppStorage("ambientMusicSignalsEnabled") var musicSignalsEnabled = false

    private let photoService = PhotoSignalService()
    private let musicService = MusicSignalService()

    private init() {}

    /// Derive today's ambient signals from whatever sources are enabled and
    /// authorized, enqueuing each for review. Safe to call more than once a day
    /// — the queue de-dupes by day+kind. Never blocks the UI; nothing reaches
    /// the Twin here (only the review queue).
    func refreshTodaySignals() async {
        let today = Calendar.current.startOfDay(for: Date())
        if photoSignalsEnabled, let signal = await photoService.deriveSignal(for: today) {
            PendingAmbientSignalQueue.shared.enqueue(signal)
        }
        if musicSignalsEnabled, let signal = await musicService.deriveSignal(for: today) {
            PendingAmbientSignalQueue.shared.enqueue(signal)
        }
    }

    // MARK: Keep — the only path by which an ambient signal reaches the Twin

    /// Keep one reviewed signal: record it as kept context and fold its derived
    /// label into the Twin.
    func fold(_ signal: AmbientSignal) {
        KeptAmbientSignalStore.shared.append(signal)
        foldIntoTwin(signal)
    }

    /// Keep a batch (the "Keep all" path).
    func fold(contentsOf signals: [AmbientSignal]) {
        KeptAmbientSignalStore.shared.append(contentsOf: signals)
        for s in signals { foldIntoTwin(s) }
    }

    private func foldIntoTwin(_ signal: AmbientSignal) {
        // v1.6 wiring hook: fold the derived label into the Twin as day-context
        // via the additive engine API `DigitalTwinEngine.foldContextNote(_:date:)`.
        // Until that engine method lands, the signal is recorded as kept context
        // (surfaced in insights); no raw media ever exists to fold — only this label.
        DigitalTwinContext.foldContextNote(signal.label, detail: signal.detail, day: signal.day)
    }

    // MARK: Permissions (value-framed, requested only when a source is enabled)

    func enablePhotoSignals() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let granted = (status == .authorized || status == .limited)
        photoSignalsEnabled = granted
        return granted
    }

    func enableMusicSignals() async -> Bool {
        let status = await MPMediaLibrary.requestAuthorization()
        let granted = (status == .authorized)
        musicSignalsEnabled = granted
        return granted
    }
}

// MARK: - Photo signals (on-device Photos + Vision)

/// Turns the day's camera roll into a one-line scene summary using on-device
/// Vision classification. Produces ONLY derived labels — the photos themselves
/// are read, classified in memory, and never copied, stored, or transmitted.
struct PhotoSignalService {
    /// Cap the number of photos classified per day so a heavy shooter doesn't
    /// spin Vision over hundreds of images.
    private let maxPhotos = 40
    /// Vision confidence floor for a scene label to count.
    private let minConfidence: VNConfidence = 0.35

    func deriveSignal(for day: Date) async -> AmbientSignal? {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) != .denied else { return nil }

        let assets = fetchAssets(for: day)
        guard !assets.isEmpty else { return nil }

        var labelCounts: [String: Int] = [:]
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false   // on-device only; no iCloud fetch

        for asset in assets.prefix(maxPhotos) {
            guard let cgImage = await requestCGImage(asset, manager: imageManager, options: options) else { continue }
            for label in classifyScenes(cgImage) {
                labelCounts[label, default: 0] += 1
            }
        }
        guard !labelCounts.isEmpty else { return nil }

        let summary = summarize(labelCounts: labelCounts, photoCount: min(assets.count, maxPhotos))
        return AmbientSignal(kind: .photo, day: day, label: summary.label, detail: summary.detail)
    }

    private func fetchAssets(for day: Date) -> [PHAsset] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                        start as NSDate, end as NSDate, PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    private func requestCGImage(_ asset: PHAsset, manager: PHImageManager, options: PHImageRequestOptions) async -> CGImage? {
        await withCheckedContinuation { continuation in
            manager.requestImage(for: asset, targetSize: CGSize(width: 299, height: 299),
                                 contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    private func classifyScenes(_ cgImage: CGImage) -> [String] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observations = request.results else { return [] }
        return observations
            .filter { $0.confidence >= minConfidence }
            .prefix(3)
            .map { $0.identifier }
    }

    /// Collapse raw Vision identifiers into a friendly one-liner. Deliberately
    /// coarse — a felt summary, not a taxonomy dump.
    private func summarize(labelCounts: [String: Int], photoCount: Int) -> (label: String, detail: String?) {
        let ranked = labelCounts.sorted { $0.value > $1.value }
        let top = ranked.first?.key ?? "photos"
        let friendly = friendlyScene(top)
        let label = "Mostly \(friendly)"
        let others = ranked.dropFirst().prefix(2).map { friendlyScene($0.key) }
        let detail = others.isEmpty ? "\(photoCount) photos today" : "also \(others.joined(separator: ", "))"
        return (label, detail)
    }

    private func friendlyScene(_ identifier: String) -> String {
        // Vision identifiers are lowercase, sometimes underscored/hierarchical.
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? identifier
    }
}

// MARK: - Music signals (on-device music library)

/// Reads recently-played tracks from the on-device music library and derives a
/// coarse listening-mood label. No ShazamKit, no network, no track list leaves
/// the device — only the derived mood word.
struct MusicSignalService {
    func deriveSignal(for day: Date) async -> AmbientSignal? {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { return nil }

        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: false, forProperty: MPMediaItemPropertyIsCloudItem))
        guard let items = query.items, !items.isEmpty else { return nil }

        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        let playedToday = items.filter { item in
            guard let last = item.lastPlayedDate else { return false }
            return last >= start && last < end
        }
        guard !playedToday.isEmpty else { return nil }

        // Coarse mood from genre mix — never a diagnosis, just what you reached for.
        var genreCounts: [String: Int] = [:]
        for item in playedToday {
            let genre = (item.genre ?? "").lowercased()
            genreCounts[moodBucket(forGenre: genre), default: 0] += 1
        }
        let topMood = genreCounts.sorted { $0.value > $1.value }.first?.key ?? "music"
        let label = moodLabel(topMood)
        let detail = "\(playedToday.count) tracks today"
        return AmbientSignal(kind: .music, day: day, label: label, detail: detail)
    }

    private func moodBucket(forGenre genre: String) -> String {
        if genre.contains("classical") || genre.contains("ambient") || genre.contains("jazz") || genre.contains("acoustic") { return "calm" }
        if genre.contains("metal") || genre.contains("punk") || genre.contains("rock") { return "intense" }
        if genre.contains("pop") || genre.contains("dance") || genre.contains("electronic") { return "upbeat" }
        if genre.contains("blues") || genre.contains("soul") || genre.contains("folk") { return "reflective" }
        return "varied"
    }

    private func moodLabel(_ mood: String) -> String {
        switch mood {
        case "calm":       return "Reached for calm music"
        case "intense":    return "Leaned into intense music"
        case "upbeat":     return "Played upbeat music"
        case "reflective": return "Reflective listening"
        default:           return "A varied listening day"
        }
    }
}
