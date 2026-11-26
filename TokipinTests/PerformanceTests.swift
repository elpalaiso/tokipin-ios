import XCTest
@testable import Tokipin

/// Timings with the shared large seed: the web trial generator over the 10 years ending
/// 2026-11-26 (SampleGenerator.archive(today:years: 10)). Prints milliseconds per operation;
/// assertions only guard behaviour, the numbers are for before/after comparison.
@MainActor
final class PerformanceTests: XCTestCase {
    static let today = DayKey(year: 2026, month: 11, day: 26)

    /// Simulator tests run on the Mac, so results go to a host file next to the build products.
    static func report(_ line: String) {
        print(line)
        let url = URL(fileURLWithPath: "/tmp/tokipin-perf.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    private func time(_ label: String, repeat count: Int = 1, _ body: () throws -> Void) rethrows {
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<count { try body() }
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000 / Double(count)
        Self.report(String(format: "PERF %@: %.2f ms", label, ms))
    }

    private func loadedStore() async throws -> (RecordStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.replaceAll(with: SampleGenerator.archive(today: Self.today, years: 10))
        return (store, dir)
    }

    func testLargeSeedShape() {
        let archive = SampleGenerator.archive(today: Self.today, years: 10)
        let items = archive.days.reduce(0) { $0 + $1.items.count }
        Self.report("PERF seed: \(archive.days.count) days, \(items) items, first \(archive.days.first!.date.string)")
        XCTAssertEqual(archive.days.first?.date.string, "2016-11-27")
        XCTAssertGreaterThan(archive.days.count, 3000)
    }

    func testTimings() async throws {
        let (store, dir) = try await loadedStore()

        // Launch: reading the file.
        let reread = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let start = CFAbsoluteTimeGetCurrent()
        await reread.load()
        Self.report(String(format: "PERF load: %.2f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000))
        XCTAssertEqual(reread.records.count, store.records.count)

        let months = CalendarRange.months(from: MonthKey(year: 2016, month: 11), through: Self.today.monthKey)
        // 월간: one MonthGrid per month asks for its days.
        time("days(in:) x all months", repeat: 5) { for m in months { _ = store.days(in: m) } }
        // 연간: one MiniMonth per month, each also checks the range.
        time("year view month summaries", repeat: 5) {
            for m in months {
                _ = Set(store.days(in: m).map(\.day))
                _ = CalendarRange.contains(m, today: Self.today, earliestRecord: store.earliestDay)
                _ = m.weeks()
            }
        }
        time("month sections", repeat: 20) {
            _ = CalendarRange.monthSections(today: Self.today, recordedMonths: store.recordedMonths, expanded: [])
        }
        time("visible months (기록한 날)", repeat: 20) {
            _ = RecordedMonths.visible(recordedMonths: store.recordedMonths, today: Self.today)
        }
        time("search 산책 (first, builds index)") { _ = store.search("산책") }
        time("search 산책", repeat: 5) { _ = store.search("산책") }
        time("search 2025.03", repeat: 5) { _ = store.search("2025.03") }
        // A day saved through the cache reads back identically.
        try store.save(day: Self.today.adding(days: -400), items: [RecordItem(kind: .place, value: "확인")])
        let check = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await check.load()
        XCTAssertEqual(check.records, store.records)
        try time("save one day", repeat: 5) {
            try store.save(day: Self.today, items: [RecordItem(kind: .word, value: "측정")])
        }
    }

    func testIndexFollowsWrites() async throws {
        let (store, _) = try await loadedStore()
        let first = try XCTUnwrap(store.earliestDay)
        let removed = try store.deleteDay(first)
        XCTAssertEqual(store.earliestDay, store.records.keys.min())
        XCTAssertFalse(store.days(in: first.monthKey).contains(first))
        try store.restoreDay(first, items: removed)
        XCTAssertEqual(store.earliestDay, first)
        let old = DayKey(year: 2001, month: 2, day: 3)
        try store.save(day: old, items: [RecordItem(kind: .word, value: "옛날")])
        XCTAssertEqual(store.earliestDay, old)
        XCTAssertTrue(store.recordedYears.contains(2001))
        XCTAssertEqual(store.search("옛날").map(\.day), [old])
        try store.deleteDay(old)
        XCTAssertFalse(store.recordedYears.contains(2001))
        XCTAssertEqual(store.earliestDay, first)
        XCTAssertTrue(store.search("옛날").isEmpty)
    }
}
