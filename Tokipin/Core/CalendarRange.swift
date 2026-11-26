import Foundation

/// Calendar range (Calendar Range handoff): which months explore shows, which are folded,
/// and which days can take a new record. Month arithmetic only; `today` is the device's
/// local date and is injected so tests and month rollover use the same path.
enum CalendarRange {
    /// Months kept fully open at the end of the range, this month included.
    static let protectedMonths = 12
    /// A run of empty months before the protected span folds into one row from this length.
    static let minFoldedMonths = 6

    /// Last explorable month: the month of the device's local date.
    static func lastMonth(today: DayKey) -> MonthKey { today.monthKey }

    /// First month of the protected recent span (11 months before this month).
    static func protectedStart(today: DayKey) -> MonthKey {
        today.monthKey.adding(months: -(protectedMonths - 1))
    }

    /// The earlier of 11 months ago and the oldest saved record's month.
    static func firstMonth(today: DayKey, earliestRecord: DayKey?) -> MonthKey {
        let recent = protectedStart(today: today)
        guard let earliest = earliestRecord?.monthKey else { return recent }
        return min(recent, earliest)
    }

    /// New records may go on any past day and up to the last day of this month.
    static func canWrite(_ day: DayKey, today: DayKey) -> Bool {
        day.monthKey <= today.monthKey
    }

    static func lastWritableDay(today: DayKey) -> DayKey {
        let month = today.monthKey
        return DayKey(year: month.year, month: month.month, day: month.numberOfDays)
    }

    static func contains(_ month: MonthKey, today: DayKey, earliestRecord: DayKey?) -> Bool {
        month >= firstMonth(today: today, earliestRecord: earliestRecord) && month <= lastMonth(today: today)
    }

    static func months(from first: MonthKey, through last: MonthKey) -> [MonthKey] {
        var result: [MonthKey] = []
        var cursor = first
        while cursor <= last {
            result.append(cursor)
            cursor = cursor.adding(months: 1)
        }
        return result
    }

    // MARK: 월간 sections

    enum MonthSection: Hashable {
        case month(MonthKey)
        /// Empty months folded into one row; both ends included.
        case gap(first: MonthKey, last: MonthKey)

        var id: String {
            switch self {
            case .month(let month): month.id
            case .gap(let first, let last): "gap-\(first.id)-\(last.id)"
            }
        }
    }

    /// Runs of ≥ 6 empty months before the protected span. A run that reaches into the protected
    /// span is judged by its part before it only.
    static func monthGaps(today: DayKey, recordedMonths: Set<MonthKey>) -> [(first: MonthKey, last: MonthKey)] {
        let first = firstMonth(today: today, earliestRecord: recordedMonths.min()?.firstDay)
        let protected = protectedStart(today: today)
        guard first < protected else { return [] }
        var gaps: [(MonthKey, MonthKey)] = []
        var runStart: MonthKey?
        var cursor = first
        while cursor < protected {
            if recordedMonths.contains(cursor) {
                if let start = runStart { appendGap(start, cursor.adding(months: -1), into: &gaps) }
                runStart = nil
            } else if runStart == nil {
                runStart = cursor
            }
            cursor = cursor.adding(months: 1)
        }
        if let start = runStart { appendGap(start, protected.adding(months: -1), into: &gaps) }
        return gaps
    }

    private static func appendGap(_ first: MonthKey, _ last: MonthKey, into gaps: inout [(MonthKey, MonthKey)]) {
        if monthCount(first, last) >= minFoldedMonths { gaps.append((first, last)) }
    }

    static func monthCount(_ first: MonthKey, _ last: MonthKey) -> Int {
        (last.year * 12 + last.month) - (first.year * 12 + first.month) + 1
    }

    /// Oldest first. `expanded` holds the first month of each gap the person opened; an open gap
    /// keeps its row (to fold it again) followed by its months.
    static func monthSections(today: DayKey, recordedMonths: Set<MonthKey>, expanded: Set<MonthKey>) -> [MonthSection] {
        let first = firstMonth(today: today, earliestRecord: recordedMonths.min()?.firstDay)
        let gaps = monthGaps(today: today, recordedMonths: recordedMonths)
        var sections: [MonthSection] = []
        var cursor = first
        let last = lastMonth(today: today)
        while cursor <= last {
            if let gap = gaps.first(where: { $0.first == cursor }) {
                sections.append(.gap(first: gap.first, last: gap.last))
                if expanded.contains(gap.first) {
                    sections += months(from: gap.first, through: gap.last).map(MonthSection.month)
                }
                cursor = gap.last.adding(months: 1)
            } else {
                sections.append(.month(cursor))
                cursor = cursor.adding(months: 1)
            }
        }
        return sections
    }

    /// The folded gap containing `month`, if any.
    static func gap(containing month: MonthKey, today: DayKey, recordedMonths: Set<MonthKey>) -> MonthKey? {
        monthGaps(today: today, recordedMonths: recordedMonths).first { month >= $0.first && month <= $0.last }?.first
    }

    // MARK: 연간 sections

    enum YearSection: Hashable {
        case year(Int)
        case gap(first: Int, last: Int)

        var id: String {
            switch self {
            case .year(let year): String(year)
            case .gap(let first, let last): "years-\(first)-\(last)"
            }
        }
    }

    /// A year stays open when it overlaps the recent 12 months or holds any record; past years
    /// with no record between them fold into one row (a single year is one row too).
    static func yearGaps(today: DayKey, recordedYears: Set<Int>, earliestRecord: DayKey?) -> [(first: Int, last: Int)] {
        let first = firstMonth(today: today, earliestRecord: earliestRecord).year
        let protectedYear = protectedStart(today: today).year
        var gaps: [(Int, Int)] = []
        var runStart: Int?
        for year in first..<max(first, protectedYear) {
            if recordedYears.contains(year) {
                if let start = runStart { gaps.append((start, year - 1)) }
                runStart = nil
            } else if runStart == nil {
                runStart = year
            }
        }
        if let start = runStart { gaps.append((start, protectedYear - 1)) }
        return gaps
    }

    static func yearSections(today: DayKey, recordedYears: Set<Int>, earliestRecord: DayKey?, expanded: Set<Int>) -> [YearSection] {
        let first = firstMonth(today: today, earliestRecord: earliestRecord).year
        let gaps = yearGaps(today: today, recordedYears: recordedYears, earliestRecord: earliestRecord)
        var sections: [YearSection] = []
        var year = first
        while year <= today.year {
            if let gap = gaps.first(where: { $0.first == year }) {
                sections.append(.gap(first: gap.first, last: gap.last))
                if expanded.contains(gap.first) { sections += (gap.first...gap.last).map(YearSection.year) }
                year = gap.last + 1
            } else {
                sections.append(.year(year))
                year += 1
            }
        }
        return sections
    }
}

extension MonthKey {
    /// "2017.06 – 2023.03" style label for folded rows.
    static func rangeLabel(_ first: MonthKey, _ last: MonthKey) -> String {
        first == last ? first.dotted : "\(first.dotted) – \(last.dotted)"
    }

    /// Spoken month, e.g. "2017년 6월", localized.
    var spokenLabel: String { String(localized: "\(String(year))년 \(month)월") }
}
