import Foundation

/// Emoji acceptance shared by typing, paste, restored drafts and saving (UX v0.1 §4).
/// Works on extended grapheme clusters (Swift `Character`) so families, skin tones,
/// flags and keycaps are kept or dropped as one unit.
enum EmojiRules {
    private static let variationSelector16: UInt32 = 0xFE0F
    private static let keycap: UInt32 = 0x20E3

    /// True if this visible character is an emoji (sequence).
    static func isEmoji(_ character: Character) -> Bool {
        let scalars = Array(character.unicodeScalars)
        guard let first = scalars.first else { return false }
        // Emoji shown as emoji by default: ☕, 🌿, 👍🏽, 🇰🇷, ZWJ families…
        if scalars.contains(where: { $0.properties.isEmojiPresentation }) { return true }
        // Text-default emoji made emoji with VS16 (❤️, ©️, ↔️) or keycaps (1️⃣, #️⃣).
        if first.properties.isEmoji,
           scalars.contains(where: { $0.value == variationSelector16 || $0.value == keycap }) {
            return true
        }
        // Plain digits, #, ©, ⌘, a lone ZWJ or combining mark are not emoji fragments.
        return false
    }

    /// Keeps only emoji characters, in their original order.
    static func filter(_ text: String) -> String {
        String(text.filter(isEmoji))
    }

    /// Result of applying an edit in the emoji field.
    struct Edit: Equatable {
        var text: String
        /// Selection after the edit, in grapheme (Character) offsets.
        var selection: Range<Int>
        var changed: Bool
    }

    /// Replaces `selection` (grapheme offsets) with the emoji part of `incoming`.
    /// When nothing valid is left the original text and selection are kept.
    static func replace(in text: String, selection: Range<Int>, with incoming: String) -> Edit {
        let accepted = filter(incoming)
        guard !accepted.isEmpty || incoming.isEmpty else {
            return Edit(text: text, selection: selection, changed: false)
        }
        var characters = Array(text)
        let lower = min(selection.lowerBound, characters.count)
        let upper = min(selection.upperBound, characters.count)
        characters.replaceSubrange(lower..<upper, with: Array(accepted))
        let caret = lower + accepted.count
        return Edit(text: String(characters), selection: caret..<caret, changed: true)
    }
}

/// Time fragments are stored as ASCII "HH:mm" wall-clock values and shown in the
/// device's 12/24-hour style (UX v0.1 §4).
enum TimeRules {
    static func components(_ value: String) -> (hour: Int, minute: Int)? {
        guard ItemValidator.isTime(value) else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return (parts[0], parts[1])
    }

    static func canonical(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Wall-clock hour and minute of a picker date, without time-zone conversion.
    static func canonical(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return canonical(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// Display parts for a given hour cycle; `dayPeriod` is "AM"/"PM" for 12-hour.
    static func displayParts(_ value: String, hourCycle: Int) -> (hour: Int, minute: Int, dayPeriod: String?)? {
        guard let (hour, minute) = components(value) else { return nil }
        guard hourCycle == 12 else { return (hour, minute, nil) }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return (h12, minute, hour < 12 ? "AM" : "PM")
    }

    /// True when the device prefers a 24-hour clock (Settings › General › Date & Time).
    static func deviceUses24Hour(locale: Locale = .autoupdatingCurrent) -> Bool {
        let key = locale.identifier
        hourCycleLock.lock()
        defer { hourCycleLock.unlock() }
        if let cached = hourCycle[key] { return cached }
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "H"
        let uses24 = !format.contains("a")
        hourCycle[key] = uses24
        return uses24
    }

    nonisolated(unsafe) private static var hourCycle: [String: Bool] = [:]
    private static let hourCycleLock = NSLock()

    /// "18:45" → "오후 6:45" or "18:45", following the device setting. Text in the app's language.
    static func display(_ value: String, uses24Hour: Bool = deviceUses24Hour()) -> String {
        guard let (hour, minute) = components(value) else { return value }
        let locale = displayLocale
        let formatter = DayKey.formatter(template: uses24Hour ? "HHmm" : "hmma", locale: locale, fixed: uses24Hour ? "HH:mm" : nil)
        return formatter.string(from: clock(hour, minute))
    }

    /// A fixed date carrying only the wall-clock time (formatting needs a Date).
    private static func clock(_ hour: Int, _ minute: Int) -> Date {
        var parts = DateComponents()
        parts.year = 2001; parts.month = 1; parts.day = 1
        parts.hour = hour
        parts.minute = minute
        return Calendar(identifier: .gregorian).date(from: parts) ?? Date()
    }

    /// The app's display language with the person's region, so en-GB reads "25 Nov 2026" while the
    /// strings come from en.lproj. A localization that names its own region (es-419, pt-BR, zh-HK) keeps it.
    static var displayLocale: Locale {
        locale(localization: Bundle.main.preferredLocalizations.first ?? "en", region: Locale.current.region)
    }

    static func locale(localization: String, region: Locale.Region?) -> Locale {
        let language = Locale.Language(identifier: localization)
        guard language.region == nil, let region else { return Locale(identifier: localization) }
        return Locale(components: Locale.Components(languageCode: language.languageCode, script: language.script,
                                                    languageRegion: region))
    }
}

extension RecordItem {
    /// Value as shown on screen and read by VoiceOver.
    var displayValue: String {
        kind == .time ? TimeRules.display(value) : value
    }
}
