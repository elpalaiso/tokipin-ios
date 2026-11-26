import XCTest
import CryptoKit
@testable import Tokipin

/// Calendar Range handoff: reference date 2026-11-26 and the shared fixture.
@MainActor
final class CalendarRangeTests: XCTestCase {
    private let today = DayKey(year: 2026, month: 11, day: 26)
    private func m(_ y: Int, _ mo: Int) -> MonthKey { MonthKey(year: y, month: mo) }

    private func fixture() throws -> RecordArchive {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tokipin/DebugFixtures/calendar-range-records.json")
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, "530bfab851281991149abe48d5f4b083d3608d3cd180e5ea53b3e79930b88744")
        return try JSONDecoder.tokipin.decode(RecordArchive.self, from: data)
    }

    private func recordedMonths(_ archive: RecordArchive) -> Set<MonthKey> {
        Set(archive.days.filter { !$0.items.isEmpty }.map(\.date.monthKey))
    }

    // MARK: Range

    func testEmptyInstallShowsRecentTwelveMonths() {
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: nil), m(2025, 12))
        XCTAssertEqual(CalendarRange.lastMonth(today: today), m(2026, 11))
        XCTAssertTrue(CalendarRange.canWrite(DayKey(year: 2026, month: 11, day: 30), today: today))
        XCTAssertFalse(CalendarRange.canWrite(DayKey(year: 2026, month: 12, day: 1), today: today))
        let sections = CalendarRange.monthSections(today: today, recordedMonths: [], expanded: [])
        XCTAssertEqual(sections.count, 12)
        XCTAssertEqual(sections.first, .month(m(2025, 12)))
        XCTAssertEqual(sections.last, .month(m(2026, 11)))
    }

    func testRecentRecordKeepsTwelveMonths() {
        let recent = DayKey(year: 2026, month: 3, day: 1)
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: recent), m(2025, 12))
    }

    func testYearBoundaryAndLeapYear() {
        let jan = DayKey(year: 2028, month: 1, day: 3)
        XCTAssertEqual(CalendarRange.firstMonth(today: jan, earliestRecord: nil), m(2027, 2))
        XCTAssertEqual(CalendarRange.lastWritableDay(today: DayKey(year: 2028, month: 2, day: 10)),
                       DayKey(year: 2028, month: 2, day: 29))
        XCTAssertEqual(CalendarRange.lastWritableDay(today: DayKey(year: 2027, month: 12, day: 31)),
                       DayKey(year: 2027, month: 12, day: 31))
        XCTAssertEqual(m(2026, 12).adding(months: 1), m(2027, 1))
    }

    // MARK: Fixture (2026-11-26)

    func testFixtureMatchesHandoff() throws {
        let archive = try fixture()
        XCTAssertEqual(archive.days.count, 512)
        XCTAssertEqual(archive.days.reduce(0) { $0 + $1.items.count }, 1632)
        let byDay = Dictionary(uniqueKeysWithValues: archive.days.map { ($0.date, $0.items.map(\.value)) })
        XCTAssertEqual(byDay[DayKey(year: 2017, month: 5, day: 14)], ["바닷가"])
        XCTAssertEqual(byDay[DayKey(year: 2023, month: 4, day: 8)], ["책방"])
    }

    func testFixtureMonthFolding() throws {
        let months = recordedMonths(try fixture())
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: months.min()?.firstDay), m(2017, 5))
        let gaps = CalendarRange.monthGaps(today: today, recordedMonths: months)
        let pairs = gaps.map { [$0.first, $0.last] }
        // 2017.06–2023.03: 70 months in one row.
        XCTAssertTrue(pairs.contains([m(2017, 6), m(2023, 3)]))
        XCTAssertEqual(CalendarRange.monthCount(m(2017, 6), m(2023, 3)), 70)
        // 2024.02–06 (5) stays open; 2024.08–2025.01 (6) folds.
        XCTAssertFalse(gaps.contains { $0.first <= m(2024, 4) && $0.last >= m(2024, 4) })
        XCTAssertTrue(pairs.contains([m(2024, 8), m(2025, 1)]))
        // Recent empty month 2026.10 is always fully shown.
        let sections = CalendarRange.monthSections(today: today, recordedMonths: months, expanded: [])
        XCTAssertTrue(sections.contains(.month(m(2026, 10))))
        XCTAssertEqual(sections.first, .month(m(2017, 5)))
        XCTAssertEqual(sections.last, .month(m(2026, 11)))

        // Opening a gap shows both ends and keeps its row to fold it again.
        let open = CalendarRange.monthSections(today: today, recordedMonths: months, expanded: [m(2024, 8)])
        let row = try XCTUnwrap(open.firstIndex(of: .gap(first: m(2024, 8), last: m(2025, 1))))
        XCTAssertEqual(open[row + 1], .month(m(2024, 8)))
        XCTAssertEqual(open[row + 6], .month(m(2025, 1)))
        XCTAssertEqual(CalendarRange.gap(containing: m(2019, 3), today: today, recordedMonths: months), m(2017, 6))
    }

    func testGapCrossingProtectedSpanCountsOnlyItsOlderPart() {
        // Records in 2025.01 and 2026.05; empty 2025.02–2026.04 crosses 2025.12.
        let months: Set<MonthKey> = [m(2025, 1), m(2026, 5)]
        let gaps = CalendarRange.monthGaps(today: today, recordedMonths: months)
        XCTAssertEqual(gaps.map { [$0.first, $0.last] }, [[m(2025, 2), m(2025, 11)]])
        // Only 4 months before the protected span: stays open.
        let short: Set<MonthKey> = [m(2025, 7)]
        XCTAssertTrue(CalendarRange.monthGaps(today: today, recordedMonths: short).isEmpty)
    }

    func testFixtureYearFolding() throws {
        let archive = try fixture()
        let years = Set(archive.days.map(\.date.year))
        let earliest = archive.days.map(\.date).min()
        let sections = CalendarRange.yearSections(today: today, recordedYears: years, earliestRecord: earliest, expanded: [])
        XCTAssertEqual(sections, [.year(2017), .gap(first: 2018, last: 2022), .year(2023), .year(2024), .year(2025), .year(2026)])
        let open = CalendarRange.yearSections(today: today, recordedYears: years, earliestRecord: earliest, expanded: [2018])
        XCTAssertEqual(open.count, sections.count + 5)
        // Months outside the range are inactive.
        XCTAssertFalse(CalendarRange.contains(m(2017, 4), today: today, earliestRecord: earliest))
        XCTAssertTrue(CalendarRange.contains(m(2017, 5), today: today, earliestRecord: earliest))
        XCTAssertFalse(CalendarRange.contains(m(2026, 12), today: today, earliestRecord: earliest))
    }

    func testWeekStartMovesTheFourteenth() {
        let day = DayKey(year: 2017, month: 5, day: 14) // Sunday
        XCTAssertEqual(day.column(firstWeekday: 1), 0)
        XCTAssertEqual(day.column(firstWeekday: 2), 6)
    }

    func testSingleEmptyYearIsOneRow() {
        let years: Set<Int> = [2022, 2024]
        let gaps = CalendarRange.yearGaps(today: today, recordedYears: years, earliestRecord: DayKey(year: 2022, month: 3, day: 1))
        XCTAssertEqual(gaps.map { [$0.first, $0.last] }, [[2023, 2023]])
    }

    func testRangeGrowsOnlyWithSavedRecords() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.replaceAll(with: try fixture())
        let early = DayKey(year: 2015, month: 9, day: 6)
        // A draft on an earlier day does not move the range.
        store.updateDraft(Draft(day: early, items: [RecordItem(kind: .word, value: "가을")], kind: .word, raw: "", editingID: nil, changed: true), for: early)
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: store.records.keys.min()), m(2017, 5))
        // Saving does.
        try store.save(day: early, items: [RecordItem(kind: .word, value: "가을")])
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: store.records.keys.min()), m(2015, 9))
        // Deleting it brings the range back; restoring extends it again.
        let removed = try store.deleteDay(early)
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: store.records.keys.min()), m(2017, 5))
        try store.restoreDay(early, items: removed)
        XCTAssertEqual(CalendarRange.firstMonth(today: today, earliestRecord: store.records.keys.min()), m(2015, 9))
    }

    // MARK: Entry date change

    private let source = DayKey(year: 2026, month: 11, day: 26)
    private let target = DayKey(year: 2017, month: 5, day: 14)

    func testNewPiecesMoveAfterTargetItemsOnce() {
        let saved = [RecordItem(kind: .word, value: "바구니")]
        let wave = RecordItem(kind: .word, value: "파도")
        let beach = RecordItem(kind: .place, value: "바닷가")
        let current = Draft(day: source, items: saved + [wave], kind: .word, raw: "", editingID: nil, changed: true)
        let outcome = EntryDateChange.change(current: current, saved: saved, to: target,
                                             targetSaved: [beach], targetDraft: nil, wholeDay: false)
        XCTAssertNil(outcome.sourceDraft, "the day left keeps its saved items as they are")
        XCTAssertEqual(outcome.targetDraft?.items.map(\.value), ["바닷가", "파도"])

        // Retrying with the same pieces against the new draft does not duplicate them.
        let again = EntryDateChange.change(current: current, saved: saved, to: target,
                                           targetSaved: [beach], targetDraft: outcome.targetDraft, wholeDay: false)
        XCTAssertEqual(again.targetDraft?.items.map(\.value), ["바닷가", "파도"])
    }

    func testTextBeingTypedTravelsWithTheDate() {
        let current = Draft(day: source, items: [], kind: .word, raw: "파도", editingID: nil, changed: false)
        let outcome = EntryDateChange.change(current: current, saved: [], to: target,
                                             targetSaved: [], targetDraft: nil, wholeDay: false)
        XCTAssertEqual(outcome.targetDraft?.raw, "파도")
        XCTAssertNil(outcome.sourceDraft)
    }

    func testTargetDraftIsNotOverwritten() {
        let kept = Draft(day: target, items: [RecordItem(kind: .word, value: "모래")], kind: .word, raw: "", editingID: nil, changed: true)
        let current = Draft(day: source, items: [RecordItem(kind: .word, value: "파도")], kind: .word, raw: "", editingID: nil, changed: true)
        let outcome = EntryDateChange.change(current: current, saved: [], to: target,
                                             targetSaved: [], targetDraft: kept, wholeDay: false)
        XCTAssertEqual(outcome.targetDraft?.items.map(\.value), ["모래", "파도"])
    }

    func testWholeDayEditKeepsChangesOnItsOwnDay() {
        let a = RecordItem(kind: .word, value: "바닷가"), b = RecordItem(kind: .place, value: "해변")
        let current = Draft(day: target, items: [b, a], kind: .word, raw: "", editingID: nil, changed: true)
        let other = DayKey(year: 2017, month: 5, day: 15)
        let outcome = EntryDateChange.change(current: current, saved: [a, b], to: other,
                                             targetSaved: [], targetDraft: nil, wholeDay: true)
        XCTAssertEqual(outcome.sourceDraft?.items.map(\.value), ["해변", "바닷가"])
        XCTAssertEqual(outcome.sourceDraft?.day, target)
        XCTAssertNil(outcome.targetDraft, "the chosen day opens as saved")

        let untouched = EntryDateChange.change(current: Draft(day: target, items: [a, b], kind: .word, raw: "", editingID: nil, changed: false),
                                               saved: [a, b], to: other, targetSaved: [], targetDraft: nil, wholeDay: true)
        XCTAssertNil(untouched.sourceDraft)
    }

    func testEditedSavedItemsStayWhenNewPiecesMove() {
        let a = RecordItem(kind: .word, value: "바구니"), b = RecordItem(kind: .word, value: "시장")
        let new = RecordItem(kind: .word, value: "파도")
        let current = Draft(day: source, items: [b, a, new], kind: .word, raw: "", editingID: nil, changed: true)
        let outcome = EntryDateChange.change(current: current, saved: [a, b], to: target,
                                             targetSaved: [], targetDraft: nil, wholeDay: false)
        XCTAssertEqual(outcome.sourceDraft?.items.map(\.value), ["시장", "바구니"])
        XCTAssertEqual(outcome.targetDraft?.items.map(\.value), ["파도"])
    }
}
