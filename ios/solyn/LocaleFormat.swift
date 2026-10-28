//
//  LocaleFormat.swift
//  solyn
//
//  Dates, numbers and quotation marks in the reader's own conventions (plan B-12).
//

import Foundation

/// The one place user-facing dates, decimals and quotes are formatted.
///
/// The app used to spell formats out by hand: `dateFormat = "EEEE, MMMM d"`,
/// `String(format: "%+.2f")`, a hard-coded pair of curly English quotes. Each
/// is correct in American English and wrong almost everywhere else: a German
/// reader got "Montag, Oktober 26" instead of "Montag, 26. Oktober", a decimal
/// point where they write a comma, and “English quotes” around their own words.
///
/// Everything here asks the locale instead. For en_US every function returns
/// exactly what the hand-written format did (the tests pin that), so American
/// English does not move. Other English locales get their own date order
/// (en_GB and en_IN read "Monday, 26 October"), which is the point.
///
/// Machine formats (CSV columns, file names, keys) are NOT user-facing and
/// must not move with the locale; they go through `posix(_:)`.
enum LocaleFormat {

    private static let lock = NSLock()
    private static var cache: [String: DateFormatter] = [:]

    /// A formatter for a skeleton such as "EEEEMMMMd", laid out the way
    /// `locale` writes it (order, punctuation, standalone month names).
    static func formatter(template: String, locale: Locale = .current,
                          timeZone: TimeZone = .current) -> DateFormatter {
        let key = "\(template)|\(locale.identifier)|\(timeZone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        cache[key] = formatter
        return formatter
    }

    /// `date` formatted from a template in `locale`.
    static func date(_ date: Date, template: String, locale: Locale = .current,
                     timeZone: TimeZone = .current) -> String {
        formatter(template: template, locale: locale, timeZone: timeZone).string(from: date)
    }

    // Templates used across the app, named for what they show.

    /// "Monday, October 26" / "Montag, 26. Oktober".
    static let weekdayMonthDay = "EEEEMMMMd"
    /// "Monday, October 26, 2026".
    static let weekdayMonthDayYear = "EEEEMMMMdy"
    /// "October 26, 2026".
    static let monthDayYear = "MMMMdy"
    /// "Oct 26".
    static let shortMonthDay = "MMMd"
    /// "October 2026" (standalone month where the language has one).
    static let monthYear = "MMMMy"
    /// "October" (standalone).
    static let month = "MMMM"
    /// "10:30 PM" / "22:30": the locale's own hour cycle.
    static let time = "jmm"
    /// "M" for Monday: the narrow weekday.
    static let narrowWeekday = "EEEEE"

    /// A fixed, locale-independent formatter for machine-readable output:
    /// CSV columns, file names. en_US_POSIX and the Gregorian calendar, so a
    /// Thai Buddhist or Japanese calendar setting cannot turn "2026" into
    /// "2569" in a file another program reads.
    static func posix(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter
    }

    // MARK: - Numbers

    /// A decimal with exactly `fractionDigits` digits, in the locale's
    /// separator: "0.4" / "0,4". `signed` always shows the sign ("+0.4"), as
    /// `%+.1f` did. Never grouped, as `String(format:)` never was.
    static func decimal(_ value: Double, fractionDigits: Int, signed: Bool = false,
                        locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumIntegerDigits = 1
        formatter.roundingMode = .halfEven
        if signed {
            formatter.positivePrefix = formatter.plusSign
            formatter.zeroSymbol = nil
        }
        // Rounded the way `String(format:)` rounds (the exact binary value,
        // so 0.15 is 0.1 and 0.05 is 0.1), and only then laid out in the
        // locale. NumberFormatter alone rounds the decimal it sees, which
        // would move American English numbers by a digit at the edges.
        let posix = String(format: "%.\(fractionDigits)f", value)
        let rounded = Double(posix) ?? value
        return formatter.string(from: NSNumber(value: rounded)) ?? posix
    }

    /// A whole-number percentage of a 0…1 fraction: "42%" / "42 %".
    static func percent(_ fraction: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfEven
        // Whole percent rounded as `%.0f` rounded it, then laid out locally.
        let whole = String(format: "%.0f", fraction * 100)
        let rounded = (Double(whole) ?? fraction * 100) / 100
        return formatter.string(from: NSNumber(value: rounded)) ?? whole + "%"
    }

    // MARK: - Quotation marks

    /// `text` between the locale's own quotation marks: “English”, „Deutsch“,
    /// «français», “español” per CLDR. Falls back to the English pair.
    static func quoted(_ text: String, locale: Locale = .current) -> String {
        let open = locale.quotationBeginDelimiter ?? "\u{201C}"
        let close = locale.quotationEndDelimiter ?? "\u{201D}"
        return open + text + close
    }
}
