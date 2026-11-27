import XCTest
@testable import Tokipin

@MainActor
final class SampleCalendarTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private let defaults = UserDefaults(suiteName: UUID().uuidString)!

    private func readStore() async -> RecordStore {
        let store = RecordStore(directory: directory, defaults: defaults)
        await store.load()
        return store
    }

    func testSamplePracticeNeverEntersDraftsRecordsSearchOrExport() async throws {
        let store = await readStore()
        XCTAssertTrue(store.needsSampleCalendar(hasUsageChoice: false))
        for date in ["2026-01-01", "2026-03-15", "2028-03-31"] {
            let today = try XCTUnwrap(DayKey(string: date))
            var sample = SampleCalendar(today: today)
            for offset in 0...2 {
                sample.month = today.monthKey.adding(months: -offset)
                let target = sample.featured
                let reservedDay = sample.reserved(in: sample.month)
                XCTAssertNotEqual(target, reservedDay)
                XCTAssertEqual(sample.items(on: target).last?.value, "🏺")
                XCTAssertTrue(sample.items(on: reservedDay).isEmpty)
                sample.beginPractice(from: target)
                XCTAssertEqual(sample.page, .practice(reservedDay))
                sample.savePractice()
                XCTAssertEqual(sample.page, .practice(reservedDay))
                sample.selectedEmoji = "🌱"
                sample.savePractice()
                XCTAssertEqual(sample.page, .month)
                XCTAssertEqual(sample.items(on: reservedDay).map(\.value), ["🌱"])
                XCTAssertEqual(sample.items(on: target).count, 3)
                sample.beginPractice(from: target)
                XCTAssertNotEqual(sample.page, .practice(reservedDay))
            }
            let restarted = SampleCalendar(today: today)
            XCTAssertTrue(restarted.saved.isEmpty)
        }
        XCTAssertNil(store.latestDraft)
        XCTAssertTrue(store.isEmpty)
        XCTAssertTrue(store.search("🌱").isEmpty)
        let archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: store.exportData())
        XCTAssertTrue(archive.days.isEmpty)
        let relaunched = await readStore()
        XCTAssertTrue(relaunched.needsSampleCalendar(hasUsageChoice: false))
    }

    func testSeedDensityAndRepeatedPracticeOnlyUsesAvailableDates() throws {
        for date in ["2026-01-01", "2026-02-15", "2028-02-29"] {
            var sample = SampleCalendar(today: try XCTUnwrap(DayKey(string: date)))
            let days = (1...sample.month.numberOfDays).map { DayKey(year: sample.month.year, month: sample.month.month, day: $0) }
            let emptyDays = days.filter { sample.items(on: $0).isEmpty }
            XCTAssertGreaterThanOrEqual(days.count - emptyDays.count, 20)
            let from = sample.featured
            for _ in emptyDays {
                sample.beginPractice(from: from)
                sample.selectedEmoji = "✨"
                sample.savePractice()
            }
            XCTAssertEqual(Set(sample.saved.keys), Set(emptyDays))
            XCTAssertNil(sample.practiceDate(from: from))
            sample.beginPractice(from: from)
            XCTAssertEqual(sample.page, .month)
            XCTAssertEqual(sample.items(on: from).last?.value, "🏺")
        }
    }

    func testOnboardingCompletionAndExistingInstallSignalsSurviveRelaunch() async throws {
        let store = await readStore()
        XCTAssertFalse(store.needsSampleCalendar(hasUsageChoice: true))
        let day = DayKey.today
        let draft = Draft(day: day, items: [], kind: .word, raw: "unfinished", changed: true)
        store.updateDraft(draft, for: day)
        let hasDraft = await readStore()
        XCTAssertFalse(hasDraft.needsSampleCalendar(hasUsageChoice: false))
        XCTAssertEqual(hasDraft.latestDraft?.raw, "unfinished")
        store.updateDraft(nil, for: day)
        try store.save(day: day, items: [RecordItem(kind: .word, value: "real")])
        let hasRecords = await readStore()
        XCTAssertFalse(hasRecords.needsSampleCalendar(hasUsageChoice: false))
        XCTAssertEqual(hasRecords.items(on: day).first?.value, "real")
        try hasRecords.save(day: day, items: [])
        let existingEmpty = await readStore()
        XCTAssertFalse(existingEmpty.needsSampleCalendar(hasUsageChoice: false))

        let fresh = RecordStore(directory: directory, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await fresh.load()
        XCTAssertTrue(fresh.needsSampleCalendar(hasUsageChoice: false))
        let untouched = UserDefaults(suiteName: UUID().uuidString)!
        let first = RecordStore(directory: directory, defaults: untouched)
        await first.load()
        first.completeSampleCalendar()
        let returned = RecordStore(directory: directory, defaults: untouched)
        await returned.load()
        XCTAssertFalse(returned.needsSampleCalendar(hasUsageChoice: false))
        XCTAssertTrue(returned.isFirstLaunch) // Interrupted before the real editor closed.
    }
}
