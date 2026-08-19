import CoreData
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

    /// Convenience for callers with a Core Data context: works out which of the
    /// coming days already have an entry, then re-arms.
    func refresh(in context: NSManagedObjectContext) {
        guard isEnabled else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: identifiers(for: horizon))
            return
        }
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let request = NSFetchRequest<NSManagedObject>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "date >= %@", from as NSDate)
        let days = ((try? context.fetch(request)) ?? []).compactMap { obj -> Date? in
            (obj.value(forKey: "date") as? Date).map { cal.startOfDay(for: $0) }
        }
        scheduleReminder(spokenDays: Set(days))
    }

    /// Re-arms the next `horizon` days of reminders, skipping any evening on
    /// which an entry already exists.
    ///
    /// A single `repeats: true` calendar trigger cannot skip a day — the system
    /// fires it whether or not you have spoken, and the Settings card promises
    /// "skips once you've spoken". So the reminders are scheduled individually,
    /// a week at a time, and re-armed whenever an entry is saved or the app
    /// comes forward. The pending list is small and iOS caps it at 64, well
    /// above a week.
    /// WHICH evenings get a reminder — the decision, with no side effects.
    ///
    /// Separated from the scheduling so it can be tested without notification
    /// authorization. Asserting on `UNUserNotificationCenter`'s pending list
    /// cannot tell "the day was correctly skipped" from "nothing was ever
    /// scheduled because permission was denied", and those look identical in a
    /// green test run.
    func plannedFireDates(spokenDays: Set<Date>, now: Date = Date()) -> [Date] {
        let cal = Calendar.current
        var out: [Date] = []
        for offset in 0..<horizon {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let start = cal.startOfDay(for: day)

            // Already spoken that day — no reminder for it.
            if spokenDays.contains(start) { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: start)
            comps.hour = reminderHour
            comps.minute = reminderMinute
            guard let fire = cal.date(from: comps), fire > now else { continue }
            out.append(fire)
        }
        return out
    }

    func scheduleReminder(spokenDays: Set<Date> = []) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: horizon))

        let cal = Calendar.current

        for (offset, fireDate) in plannedFireDates(spokenDays: spokenDays).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Tonight's star is waiting"
            // No streak guilt, and it names the size of the ask: small
            // commitments get acted on, and 42s is the product's own unit.
            content.body = "Whenever you're ready. Forty-two seconds."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute],
                                                 from: fireDate),
                repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(notificationIdentifier).\(offset)",
                content: content, trigger: trigger)

            center.add(request) { error in
                if let error {
                    logger.error("Failed to schedule reminder: \(error.localizedDescription)")
                }
            }
        }
    }

    /// How many days ahead to arm. Long enough that a user who does not open
    /// the app for a few days still gets reminded, short enough that stale
    /// reminders cannot outlive a change of mind about the time.
    private var horizon: Int { 7 }

    private func identifiers(for days: Int) -> [String] {
        (0..<days).map { "\(notificationIdentifier).\($0)" } + [notificationIdentifier]
    }


    func cancelReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
