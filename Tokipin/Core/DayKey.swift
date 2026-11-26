import Foundation

/// A calendar day independent of time zone, stored as "yyyy-MM-dd".
struct DayKey: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        return calendar
    }()

    /// Short weekday names, Sunday first. Localizable (keys weekday.sun … weekday.sat).
    static var weekdaySymbols: [String] {
        [
            String(localized: "weekday.sun", defaultValue: "일"),
            String(localized: "weekday.mon", defaultValue: "월"),
            String(localized: "weekday.tue", defaultValue: "화"),
            String(localized: "weekday.wed", defaultValue: "수"),
            String(localized: "weekday.thu", defaultValue: "목"),
            String(localized: "weekday.fri", defaultValue: "금"),
            String(localized: "weekday.sat", defaultValue: "토")
        ]
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    static var today: DayKey { DayKey(date: Date()) }

    var id: String { string }

    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// 0 = Sunday … 6 = Saturday.
    var weekday: Int { Self.calendar.component(.weekday, from: date) - 1 }

    var weekdaySymbol: String { Self.weekdaySymbols[weekday] }

    var monthKey: MonthKey { MonthKey(year: year, month: month) }

    func adding(days: Int) -> DayKey {
        DayKey(date: Self.calendar.date(byAdding: .day, value: days, to: date)!)
    }

    /// Device week start (1 = Sunday, 2 = Monday …), from the region settings even when
    /// the app language is Korean.
    static var deviceFirstWeekday: Int { Calendar.autoupdatingCurrent.firstWeekday }

    /// 0-based column of this day in a week that starts on `firstWeekday`.
    func column(firstWeekday: Int = DayKey.deviceFirstWeekday) -> Int {
        (weekday - (firstWeekday - 1) + 7) % 7
    }

    /// First day of this day's week.
    func weekStart(firstWeekday: Int = DayKey.deviceFirstWeekday) -> DayKey {
        adding(days: -column(firstWeekday: firstWeekday))
    }

    /// Weekday names in display order for the given week start.
    static func orderedWeekdaySymbols(firstWeekday: Int = DayKey.deviceFirstWeekday) -> [String] {
        let symbols = weekdaySymbols
        return (0..<7).map { symbols[($0 + firstWeekday - 1) % 7] }
    }

    var string: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// 2026.11.25
    var dotted: String { String(format: "%04d.%02d.%02d", year, month, day) }

    /// 2026.11.25(수)
    var label: String { "\(dotted)(\(weekdaySymbol))" }

    /// 2026.11.25 (수) — editor header.
    var spacedLabel: String { "\(dotted) (\(weekdaySymbol))" }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension DayKey: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = DayKey(string: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid day \(raw)")
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

struct MonthKey: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int

    var id: String { String(format: "%04d-%02d", year, month) }

    var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }

    var numberOfDays: Int {
        DayKey.calendar.range(of: .day, in: .month, for: firstDay.date)!.count
    }

    /// 2026.11
    var dotted: String { String(format: "%04d.%02d", year, month) }

    func adding(months: Int) -> MonthKey {
        let total = year * 12 + (month - 1) + months
        return MonthKey(year: total / 12, month: total % 12 + 1)
    }

    /// Day numbers laid out in weeks; nil for leading/trailing blanks. Cached: the month and
    /// year grids ask for every visible month on each render.
    func weeks(firstWeekday: Int = DayKey.deviceFirstWeekday) -> [[Int?]] {
        let key = WeeksKey(month: self, firstWeekday: firstWeekday)
        MonthKey.weeksLock.lock()
        defer { MonthKey.weeksLock.unlock() }
        if let cached = MonthKey.weeksCache[key] { return cached }
        let value = computeWeeks(firstWeekday: firstWeekday)
        MonthKey.weeksCache[key] = value
        return value
    }

    private struct WeeksKey: Hashable { let month: MonthKey; let firstWeekday: Int }
    nonisolated(unsafe) private static var weeksCache: [WeeksKey: [[Int?]]] = [:]
    private static let weeksLock = NSLock()

    private func computeWeeks(firstWeekday: Int) -> [[Int?]] {
        let lead = firstDay.column(firstWeekday: firstWeekday)
        var cells: [Int?] = Array(repeating: nil, count: lead) + (1...numberOfDays).map { $0 }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
