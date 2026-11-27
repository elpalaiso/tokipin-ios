import Foundation

/// All browsing and practice state is held by the sample view for the duration of its presentation.
struct SampleCalendar {
    enum Page: Equatable {
        case month
        case day(DayKey)
        case practice(DayKey)
    }

    static let emoji = ["🌱", "☕", "🌧️", "✨"]
    private static let filled = [1, 3, 5, 7, 9, 11, 13, 17, 19, 21, 23, 25, 27, 2, 6, 10, 16, 18, 22, 26, 29]
    private static let examples: [(String, String, String)] = [
        (String(localized: "산책"), String(localized: "공원"), "🌿"),
        (String(localized: "커피"), String(localized: "카페"), "☕"),
        (String(localized: "독서"), String(localized: "도서관"), "📚"),
        (String(localized: "자전거 타기"), String(localized: "산책로"), "🚲"),
        (String(localized: "요리"), String(localized: "부엌"), "🍲")
    ]

    private let today: DayKey
    var month: MonthKey
    var page = Page.month
    var guides = true
    var selectedEmoji: String?
    private(set) var saved: [DayKey: RecordItem] = [:]
    private(set) var lastSaved: DayKey?

    init(today: DayKey = .today) {
        self.today = today
        month = today.monthKey
    }

    var months: ClosedRange<MonthKey> { today.monthKey.adding(months: -2)...today.monthKey }

    func reserved(in month: MonthKey) -> DayKey {
        DayKey(year: month.year, month: month.month, day: min(today.day, month.numberOfDays))
    }

    var featured: DayKey {
        DayKey(year: month.year, month: month.month, day: reserved(in: month).day == 15 ? 14 : 15)
    }

    func items(on day: DayKey) -> [RecordItem] {
        if let item = saved[day] { return [item] }
        let reservedDay = reserved(in: day.monthKey)
        guard day != reservedDay else { return [] }
        let sample: (String, String, String)
        if day.day == (reservedDay.day == 15 ? 14 : 15) {
            sample = (String(localized: "도예"), String(localized: "작업실"), "🏺")
        } else if let index = Self.filled.firstIndex(of: day.day) {
            sample = Self.examples[index % Self.examples.count]
        } else {
            return []
        }
        return [(ItemKind.word, sample.0), (.place, sample.1), (.emoji, sample.2)].enumerated().map { index, entry in
            // A date's fragments keep their identity across renders.
            let id = String(format: "00000000-0000-4000-8000-%04d%02d%02d%04d", day.year, day.month, day.day, index)
            return RecordItem(id: UUID(uuidString: id)!, kind: entry.0, value: entry.1)
        }
    }

    func practiceDate(from day: DayKey) -> DayKey? {
        let reservedDay = reserved(in: day.monthKey)
        let candidates = [day, reservedDay] + (1...day.monthKey.numberOfDays).map {
            DayKey(year: day.year, month: day.month, day: $0)
        }
        return candidates.first { items(on: $0).isEmpty }
    }

    mutating func beginPractice(from day: DayKey) {
        guard let destination = practiceDate(from: day) else { return }
        selectedEmoji = nil
        page = .practice(destination)
    }

    mutating func savePractice() {
        guard case let .practice(day) = page, let selectedEmoji, Self.emoji.contains(selectedEmoji) else { return }
        saved[day] = RecordItem(kind: .emoji, value: selectedEmoji)
        lastSaved = day
        month = day.monthKey
        page = .month
        guides = false
        self.selectedEmoji = nil
    }
}
