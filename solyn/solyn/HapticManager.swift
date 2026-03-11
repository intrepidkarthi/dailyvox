//
//  HapticManager.swift
//  solyn
//
//  Centralized haptic feedback manager for consistent tactile feedback.
//  Provides subtle, non-intrusive haptics for key user actions.
//

import SwiftUI

#if os(iOS)
import UIKit

/// Centralized manager for haptic feedback throughout the app.
/// All haptics are subtle and designed to enhance, not distract.
final class HapticManager {
    
    // MARK: - Shared Instance
    
    static let shared = HapticManager()
    
    // MARK: - Feedback Generators
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    // MARK: - Initialization
    
    private init() {
        // Prepare generators for faster response
        prepareAll()
    }
    
    /// Prepare all generators for immediate feedback
    func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactSoft.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    // MARK: - Recording Haptics
    
    /// Subtle haptic when recording starts
    func recordingStarted() {
        impactMedium.impactOccurred(intensity: 0.7)
    }
    
    /// Satisfying haptic when recording stops
    func recordingStopped() {
        impactSoft.impactOccurred(intensity: 0.8)
    }
    
    // MARK: - Entry Haptics
    
    /// Success haptic when entry is saved
    func entrySaved() {
        notification.notificationOccurred(.success)
    }
    
    /// Haptic when entry is deleted
    func entryDeleted() {
        notification.notificationOccurred(.warning)
    }
    
    /// Haptic when entry is starred/unstarred
    func entryStarred() {
        impactLight.impactOccurred(intensity: 0.6)
    }
    
    // MARK: - UI Haptics
    
    /// Light tap for button presses
    func buttonTap() {
        impactLight.impactOccurred(intensity: 0.5)
    }
    
    /// Selection changed (picker, segment)
    func selectionChanged() {
        selection.selectionChanged()
    }
    
    /// Tab changed
    func tabChanged() {
        impactLight.impactOccurred(intensity: 0.4)
    }
    
    /// Pull to refresh triggered
    func pullToRefresh() {
        impactMedium.impactOccurred(intensity: 0.5)
    }
    
    /// Theme changed
    func themeChanged() {
        impactSoft.impactOccurred(intensity: 0.6)
    }
    
    // MARK: - Mood Haptics
    
    /// Haptic when mood is selected
    func moodSelected() {
        impactLight.impactOccurred(intensity: 0.5)
    }
    
    // MARK: - Error Haptics
    
    /// Error occurred
    func error() {
        notification.notificationOccurred(.error)
    }
    
    /// Warning
    func warning() {
        notification.notificationOccurred(.warning)
    }
    
    // MARK: - Streak Haptics
    
    /// Celebration for streak milestone
    func streakMilestone() {
        // Double tap pattern for celebration
        impactMedium.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactHeavy.impactOccurred(intensity: 0.6)
        }
    }
}

#else
// Stub for non-iOS platforms
final class HapticManager {
    static let shared = HapticManager()
    private init() {}
    
    func prepareAll() {}
    func recordingStarted() {}
    func recordingStopped() {}
    func entrySaved() {}
    func entryDeleted() {}
    func entryStarred() {}
    func buttonTap() {}
    func selectionChanged() {}
    func tabChanged() {}
    func pullToRefresh() {}
    func themeChanged() {}
    func moodSelected() {}
    func error() {}
    func warning() {}
    func streakMilestone() {}
}
#endif
