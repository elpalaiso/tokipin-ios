import Foundation

/// 기록한 날 pages (Native UX v0.3): months that hold at least one saved item, plus this month,
/// in calendar order. Body swipes, the rail, taps, flings and VoiceOver all step through this
/// list by index and identify months by their year-month key.
enum RecordedMonths {
    /// Unique months of saved days up to this month, plus this month; oldest first.
    /// Drafts never count, and saved future months are left out of this view.
    static func visible(recordedDays: some Sequence<DayKey>, today: DayKey) -> [MonthKey] {
        visible(recordedMonths: Set(recordedDays.map(\.monthKey)), today: today)
    }

    /// Same, from the store's month index (no scan over every day).
    static func visible(recordedMonths: Set<MonthKey>, today: DayKey) -> [MonthKey] {
        let current = today.monthKey
        var months = recordedMonths.filter { $0 <= current }
        months.insert(current)
        return months.sorted()
    }

    /// `month` if it is shown; otherwise the shown month with the smallest calendar distance,
    /// the more recent one on a tie.
    static func resolve(_ month: MonthKey, in months: [MonthKey]) -> MonthKey {
        guard !months.contains(month), let first = months.first else { return month }
        var best = first
        for candidate in months {
            let d = distance(candidate, month), b = distance(best, month)
            if d < b || (d == b && candidate > best) { best = candidate }
        }
        return best
    }

    /// The neighbour `step` slots away, or nil past either end (the edges stay empty).
    static func neighbour(of month: MonthKey, step: Int, in months: [MonthKey]) -> MonthKey? {
        guard let index = months.firstIndex(of: resolve(month, in: months)) else { return nil }
        let target = index + step
        return months.indices.contains(target) ? months[target] : nil
    }

    /// Slots around the committed month; nil where the list has ended.
    static func window(committed: MonthKey, sideSlots: Int, in months: [MonthKey]) -> [MonthKey?] {
        (-sideSlots...sideSlots).map { neighbour(of: committed, step: $0, in: months) }
    }

    /// Small 4-digit year over one slot per other year: the slot nearest the centre.
    /// Nothing over months in the committed month's year.
    static func hints(window: [MonthKey?], committed: MonthKey) -> [String?] {
        let centre = window.count / 2
        var nearest: [Int: Int] = [:]   // year → slot index
        for (index, month) in window.enumerated() {
            guard let month, month.year != committed.year else { continue }
            if let current = nearest[month.year], abs(current - centre) <= abs(index - centre) { continue }
            nearest[month.year] = index
        }
        return window.indices.map { index in
            nearest.first { $0.value == index }.map { String($0.key) }
        }
    }

    /// Hints over the whole list, keyed by month: for each other year, the month nearest the
    /// committed slot. On screen this equals `hints(window:)`, and months scrolled in by hand
    /// already carry the right year before the rail settles.
    static func hints(committed: MonthKey, in months: [MonthKey]) -> [MonthKey: String] {
        guard let centre = months.firstIndex(of: committed) else { return [:] }
        var nearest: [Int: Int] = [:]
        for (index, month) in months.enumerated() where month.year != committed.year {
            if let current = nearest[month.year], abs(current - centre) <= abs(index - centre) { continue }
            nearest[month.year] = index
        }
        return Dictionary(uniqueKeysWithValues: nearest.map { (months[$0.value], String($0.key)) })
    }

    /// Fully visible side slots for a rail of this width.
    static func sideSlots(railWidth: CGFloat, slot: CGFloat) -> Int {
        guard slot > 0 else { return 0 }
        return max(Int(((railWidth - slot) / 2) / slot), 0)
    }

    static func distance(_ a: MonthKey, _ b: MonthKey) -> Int {
        abs((a.year * 12 + a.month) - (b.year * 12 + b.month))
    }
}

/// Centre titles per view (Native UX v0.3 §1).
enum DateHeader {
    /// 일간: year and month of the selected day ("2017.05").
    static func day(_ day: DayKey) -> String { day.monthKey.dotted }
    /// 기록한 날: the committed month's year; 월간: the visible month's year.
    static func year(_ month: MonthKey) -> String { String(month.year) }
    /// 입력: the whole draft date ("2017.05.14").
    static func editor(_ day: DayKey) -> String { day.dotted }
}
