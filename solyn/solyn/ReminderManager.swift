import Foundation
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.dailyvox.app", category: "ReminderManager")

final class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    private let reminderEnabledKey = "solyn_reminder_enabled"
    private let reminderHourKey = "solyn_reminder_hour"
    private let reminderMinuteKey = "solyn_reminder_minute"
    private let notificationIdentifier = "solyn_daily_reminder"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: reminderEnabledKey)
            if isEnabled {
                scheduleReminder()
            } else {
                cancelReminder()
            }
        }
    }

    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: reminderHourKey)
            if isEnabled { scheduleReminder() }
        }
    }

    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: reminderMinuteKey)
            if isEnabled { scheduleReminder() }
        }
    }

    var reminderTime: Date {
        get {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? 20
            reminderMinute = components.minute ?? 0
        }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: reminderEnabledKey)
        self.reminderHour = UserDefaults.standard.object(forKey: reminderHourKey) as? Int ?? 20
        self.reminderMinute = UserDefaults.standard.object(forKey: reminderMinuteKey) as? Int ?? 0
    }

    func requestPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                } else {
                    completion(settings.authorizationStatus == .authorized)
                }
            }
        }
    }

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "DailyVox"
        content.body = "Take a minute to speak about your day."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    func cancelReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
