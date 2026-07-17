import Foundation

/// A thin seam between kept ambient signals (v1.5.5) and the Twin. Ambient
/// signals are derived one-line labels ("Mostly trail photos"), not diary
/// entries — folding them as lightweight day-context needs an additive engine
/// method (`DigitalTwinEngine.foldContextNote`). This seam lets the app ship
/// the full capture → review → keep gate independently of that engine change:
/// today it retains the kept context locally; the v1.6 app-wiring step points
/// `foldContextNote` at the engine so kept signals influence themes and mood.
enum DigitalTwinContext {
    private static let key = "keptAmbientContextNotes"

    /// Record a kept ambient label as day-context. Idempotent-ish (append-only,
    /// deduped by day+label). Local until the engine fold API is wired.
    static func foldContextNote(_ label: String, detail: String?, day: Date) {
        var notes = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        let dayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: day))
        let already = notes.contains { ($0["day"] as? String) == dayKey && ($0["label"] as? String) == label }
        guard !already else { return }
        notes.append(["day": dayKey, "label": label, "detail": detail ?? ""])
        if notes.count > 200 { notes.removeFirst(notes.count - 200) }
        UserDefaults.standard.set(notes, forKey: key)

        // v1.6 wiring: route to the engine so the label reaches themes/mood.
        // DigitalTwinEngine.shared.foldContextNote(label, date: day)
    }
}
