//
//  GoalManager.swift
//  solyn
//
//  Manages journaling goals and milestone tracking.
//

import Foundation
import UserNotifications
import CoreData

final class GoalManager: ObservableObject {
    static let shared = GoalManager()

    private let goalEnabledKey = "dvx_goal_enabled"
    private let goalTargetKey = "dvx_goal_target"
    private let goalNotifyKey = "dvx_goal_notify"
    private let lastMilestoneKey = "dvx_last_milestone"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: goalEnabledKey) }
    }

    @Published var weeklyTarget: Int {
        didSet {
            UserDefaults.standard.set(weeklyTarget, forKey: goalTargetKey)
        }
    }

    @Published var notifyOnGoal: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnGoal, forKey: goalNotifyKey)
        }
    }

    static let milestones = [7, 14, 30, 50, 100, 200, 365]

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: goalEnabledKey)
        let savedTarget = UserDefaults.standard.integer(forKey: goalTargetKey)
        self.weeklyTarget = savedTarget > 0 ? savedTarget : 3
        self.notifyOnGoal = UserDefaults.standard.bool(forKey: goalNotifyKey)
    }

    // MARK: - Weekly Progress

    func entriesThisWeek(from entries: [DiaryEntry]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }

        let uniqueDays = Set(entries.compactMap { entry -> Date? in
            guard let date = entry.date, date >= weekStart else { return nil }
            return calendar.startOfDay(for: date)
        })

        return uniqueDays.count
    }

    func progressThisWeek(from entries: [DiaryEntry]) -> Double {
        guard weeklyTarget > 0 else { return 0 }
        return min(1.0, Double(entriesThisWeek(from: entries)) / Double(weeklyTarget))
    }

    func daysRemainingInWeek() -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // Week starts on Sunday (1), so remaining = 7 - weekday + 1
        return 8 - weekday
    }

    // MARK: - Milestone Tracking

    func checkMilestone(currentStreak: Int) -> Int? {
        let lastMilestone = UserDefaults.standard.integer(forKey: lastMilestoneKey)

        for milestone in Self.milestones {
            if currentStreak >= milestone && milestone > lastMilestone {
                UserDefaults.standard.set(milestone, forKey: lastMilestoneKey)
                return milestone
            }
        }

        return nil
    }

    // MARK: - Goal Notification

    func scheduleGoalNotification(entriesThisWeek: Int) {
        guard notifyOnGoal, isEnabled else { return }
        guard entriesThisWeek >= weeklyTarget else { return }

        let center = UNUserNotificationCenter.current()
        let id = "dvx_goal_reached"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Goal Reached!"
        content.body = "You hit your weekly journaling goal of \(weeklyTarget) entries. Keep it up!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
