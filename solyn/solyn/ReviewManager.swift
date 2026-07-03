import StoreKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.dailyvox.app", category: "ReviewManager")

@MainActor
final class ReviewManager {
    static let shared = ReviewManager()

    private let entryCountKey = "reviewManager_entryCount"
    private let lastReviewRequestKey = "reviewManager_lastRequest"
    private let hasReviewedKey = "reviewManager_hasReviewed"

    private init() {}

    /// Call this every time a new entry is saved
    func recordEntry() {
        let count = UserDefaults.standard.integer(forKey: entryCountKey) + 1
        UserDefaults.standard.set(count, forKey: entryCountKey)
        logger.info("Entry count for review: \(count)")
        checkAndRequestReview(entryCount: count)
    }

    /// Call after a genuinely positive moment (e.g. sharing a personality card),
    /// once the user has a little history. Requests a review within Apple's caps.
    func recordPositiveMoment() {
        guard !UserDefaults.standard.bool(forKey: hasReviewedKey) else { return }
        // Needs some history so it never fires on a brand-new install.
        guard UserDefaults.standard.integer(forKey: entryCountKey) >= 2 else { return }
        if let lastRequest = UserDefaults.standard.object(forKey: lastReviewRequestKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSince >= 90 else { return }
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            await requestReview()
        }
    }

    private func checkAndRequestReview(entryCount: Int) {
        guard !UserDefaults.standard.bool(forKey: hasReviewedKey) else { return }

        // First ask at 3 (most users never reached the old floor of 5).
        let milestones = [3, 12, 40]
        guard milestones.contains(entryCount) else { return }

        if let lastRequest = UserDefaults.standard.object(forKey: lastReviewRequestKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSince >= 90 else { return }
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            await requestReview()
        }
    }

    private func requestReview() {
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestKey)
        logger.info("Requesting app review")

        if let scene = currentWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private var currentWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    func markAsReviewed() {
        UserDefaults.standard.set(true, forKey: hasReviewedKey)
    }
}
