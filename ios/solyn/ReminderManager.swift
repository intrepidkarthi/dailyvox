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
    private let quotePastKey = "solyn_reminder_quote_past"
    private let notificationIdentifier = "solyn_daily_reminder"
    /// The one note past the horizon. A suffix of the daily identifier so it
    /// is visibly part of the same family when reading the pending list.
    private let welcomeBackIdentifier = "solyn_daily_reminder.welcome_back"

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

    /// Whether the evening reminder may quote a line from a week ago.
    ///
    /// OFF unless the user turns it on, and Settings says why: a notification
    /// is shown on the lock screen, so anything it quotes can be read by
    /// whoever picks the phone up. A journal says nothing out loud by default.
    /// Every change re-arms the pending week at once, so switching it off
    /// takes the quotes off reminders already scheduled, not just future ones.
    @Published var includesPastLine: Bool {
        didSet {
            UserDefaults.standard.set(includesPastLine, forKey: quotePastKey)
            if isEnabled { refresh(in: PersistenceController.shared.container.viewContext) }
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
        self.includesPastLine = UserDefaults.standard.bool(forKey: quotePastKey)
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
            cancelReminder()
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // With quoting on, reach back to tonight's week-ago day — the
        // earliest any evening in the horizon quotes from.
        let from = includesPastLine
            ? cal.date(byAdding: .day, value: -7, to: today) ?? today
            : today
        let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "date >= %@", from as NSDate)
        let entries = (try? context.fetch(request)) ?? []
        let days = entries.compactMap { $0.date }.filter { $0 >= today }.map { cal.startOfDay(for: $0) }
        scheduleReminder(spokenDays: Set(days),
                         pastEntries: includesPastLine ? PastEntry.snapshots(of: entries) : [])
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

    /// One notification the plan wants armed: which slot it occupies, when it
    /// fires and what it says.
    struct PlannedReminder: Equatable {
        let identifier: String
        let fireDate: Date
        let title: String
        let body: String
    }

    /// The full plan — the week of evening reminders plus the one welcome-back
    /// note — with no side effects, so the identifier coverage `cancelReminder`
    /// depends on can be asserted without notification authorization.
    ///
    /// `quotePast` defaults to the user's setting. Only when it is on, and
    /// only for an evening exactly a week after an entry in `pastEntries`,
    /// does a reminder quote one; every other reminder keeps the generic copy.
    /// Exactly a week, not the Today card's 6-to-8-day fallback: with the
    /// fallback one entry would be quoted three evenings running.
    func plannedReminders(spokenDays: Set<Date>, now: Date = Date(),
                          pastEntries: [PastEntry] = [],
                          quotePast: Bool? = nil) -> [PlannedReminder] {
        let quoting = quotePast ?? includesPastLine
        var out = plannedFireDates(spokenDays: spokenDays, now: now).enumerated().map { offset, fire in
            let past = quoting
                ? Resurfacing.weekAgo(in: pastEntries, now: fire, offsets: [7],
                                      limit: Resurfacing.notificationExcerptLimit)
                : nil
            return PlannedReminder(
                identifier: "\(notificationIdentifier).\(offset)",
                fireDate: fire,
                title: String(localized: "Tonight's star is waiting",
                              comment: "Evening reminder notification title."),
                // No streak guilt, and it names the size of the ask: small
                // commitments get acted on, and 42s is the product's own unit.
                body: past.map(Self.pastLineBody)
                    ?? String(localized: "Whenever you're ready. Forty-two seconds.",
                              comment: "Evening reminder notification body."))
        }
        if let fire = welcomeBackDate(now: now) {
            out.append(PlannedReminder(
                identifier: welcomeBackIdentifier,
                fireDate: fire,
                title: String(localized: "Your sky is still here",
                              comment: "One-off notification a few days after the weekly reminders run out. No streak guilt."),
                body: String(localized: "No catching up to do. Forty-two seconds, whenever you're ready.",
                             comment: "Body of the one-off welcome-back notification. No streak guilt.")))
        }
        return out
    }

    /// The opt-in body: the entry's own words, quoted. Nothing added to them.
    static func pastLineBody(_ past: Resurfaced) -> String {
        String(localized: "A week ago you said: \u{201C}\(past.excerpt)\u{201D}",
               comment: "Opt-in evening reminder body quoting the user's own entry from a week ago. The quote is verbatim; keep it in quotation marks.")
    }

    /// When the single welcome-back note fires: `welcomeBackDay` days out, at
    /// the usual reminder time.
    ///
    /// The week of reminders is only re-armed when the app comes forward or an
    /// entry is saved, so someone who steps away for longer than the horizon
    /// used to get silence from day 8 on — the app simply went quiet. This is
    /// one gentle note past that edge, never a series: it does not count missed
    /// days, mention a streak or escalate, and every re-arm pushes it out again,
    /// so anyone who keeps opening the app never sees it at all.
    func welcomeBackDate(now: Date = Date()) -> Date? {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: welcomeBackDay,
                                 to: cal.startOfDay(for: now)) else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = reminderHour
        comps.minute = reminderMinute
        return cal.date(from: comps)
    }

    func scheduleReminder(spokenDays: Set<Date> = [], pastEntries: [PastEntry] = []) {
        let center = UNUserNotificationCenter.current()
        // Clears the welcome-back note too: it is replaced on every re-arm,
        // never stacked.
        withdrawAll(from: center)

        let cal = Calendar.current

        for planned in plannedReminders(spokenDays: spokenDays, pastEntries: pastEntries) {
            let content = UNMutableNotificationContent()
            content.title = planned.title
            content.body = planned.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute],
                                                 from: planned.fireDate),
                repeats: false)
            let request = UNNotificationRequest(
                identifier: planned.identifier,
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

    /// Three days past the last evening the week covers: long enough that it
    /// is not just another reminder, soon enough that the habit is still warm.
    private var welcomeBackDay: Int { 10 }

    private func identifiers(for days: Int) -> [String] {
        (0..<days).map { "\(notificationIdentifier).\($0)" } + [notificationIdentifier]
    }

    /// Every identifier this manager schedules under: the week's numbered
    /// slots, the bare identifier the old repeating trigger used (so an install
    /// upgraded from that build is cleaned up too), and the welcome-back note.
    var cancellableIdentifiers: [String] {
        identifiers(for: horizon) + [welcomeBackIdentifier]
    }

    /// Turning reminders off has to mean off. This used to remove only the
    /// bare identifier, which nothing schedules any more — the week of
    /// numbered reminders survived it, so someone who switched reminders off
    /// went on being reminded for up to seven more evenings.
    func cancelReminder() {
        withdrawAll(from: UNUserNotificationCenter.current())
    }

    /// Takes back every reminder under `cancellableIdentifiers` — the ones
    /// still waiting AND the ones that already fired. A delivered reminder
    /// stays in Notification Center and on the lock screen until removed, so
    /// clearing only the pending list would leave an opted-in quote readable
    /// after quoting is switched off or its entry is edited or deleted. Every
    /// one of those paths re-arms through `scheduleReminder` or
    /// `cancelReminder`, so both sets are cleared here, together, every time;
    /// `ReminderCancelTests` holds the plan's identifiers to this list.
    private func withdrawAll(from center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: cancellableIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: cancellableIdentifiers)
    }
}
