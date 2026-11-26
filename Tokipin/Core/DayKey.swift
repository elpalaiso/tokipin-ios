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

    static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

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

    /// Sunday of this day's week.
    var weekStart: DayKey { adding(days: -weekday) }

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

    /// Day numbers laid out in Sunday-first weeks; nil for leading/trailing blanks.
    var weeks: [[Int?]] {
        let lead = firstDay.weekday
        var cells: [Int?] = Array(repeating: nil, count: lead) + (1...numberOfDays).map { $0 }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
