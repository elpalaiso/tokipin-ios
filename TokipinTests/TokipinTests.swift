import XCTest
@testable import Tokipin

final class ValidatorTests: XCTestCase {
    func testTimeFormat() {
        XCTAssertEqual(ItemValidator.normalize(.time, "07:30"), .value("07:30"))
        XCTAssertEqual(ItemValidator.normalize(.time, "24:00"), .invalid)
        XCTAssertEqual(ItemValidator.normalize(.time, "7:30"), .invalid)
    }

    func testEmojiNeedsPictograph() {
        XCTAssertEqual(ItemValidator.normalize(.emoji, "🌧️"), .value("🌧️"))
        XCTAssertEqual(ItemValidator.normalize(.emoji, "🇰🇷"), .value("🇰🇷"))
        XCTAssertEqual(ItemValidator.normalize(.emoji, "비"), .invalid)
        XCTAssertEqual(ItemValidator.normalize(.emoji, "1"), .invalid)
    }

    func testWhitespaceIsEmpty() {
        XCTAssertEqual(ItemValidator.normalize(.word, "   "), .empty)
        XCTAssertEqual(ItemValidator.normalize(.place, " 연남동 "), .value("연남동"))
    }
}

final class DayKeyTests: XCTestCase {
    func testLabelsAndWeeks() {
        let day = DayKey(year: 2026, month: 11, day: 25)
        XCTAssertEqual(day.label, "2026.11.25(수)")
        XCTAssertEqual(day.weekStart(firstWeekday: 1), DayKey(year: 2026, month: 11, day: 22))
        XCTAssertEqual(DayKey(string: "2026-11-25"), day)
        XCTAssertEqual(MonthKey(year: 2026, month: 11).weeks(firstWeekday: 1).count, 5)
        XCTAssertEqual(MonthKey(year: 2026, month: 12).adding(months: 1), MonthKey(year: 2027, month: 1))
    }
}

@MainActor
final class EditorModelTests: XCTestCase {
    func testCommitKeepsOrderAndEditsInPlace() {
        let model = EditorModel(day: .today, items: [], draft: nil)
        model.raw = "첫서리"; XCTAssertTrue(model.commitRaw())
        model.setKind(.time); model.raw = "07:15"; model.commitRaw()
        model.setKind(.place); model.raw = "창가 자리"; model.commitRaw()
        XCTAssertEqual(model.items.map(\.value), ["첫서리", "07:15", "창가 자리"])

        model.edit(model.items[0])
        model.raw = "살구잼"
        model.commitRaw()
        XCTAssertEqual(model.items.map(\.value), ["살구잼", "07:15", "창가 자리"])
    }

    func testInvalidInputBlocksKindSwitch() {
        let model = EditorModel(day: .today, items: [], draft: nil)
        model.setKind(.emoji)
        model.raw = "abc"
        model.setKind(.word)
        XCTAssertEqual(model.kind, .emoji)
        XCTAssertNotNil(model.notice)
    }

    func testDeleteAndUndoRestoresOrder() {
        let items = ["귤", "서울숲", "🧣"].map { RecordItem(kind: .word, value: $0) }
        let model = EditorModel(day: .today, items: items, draft: nil)
        model.delete(ids: [items[1].id, items[2].id])
        XCTAssertEqual(model.items.map(\.value), ["귤"])
        model.undoDelete()
        XCTAssertEqual(model.items.map(\.value), ["귤", "서울숲", "🧣"])
    }
}

@MainActor
final class RecordStoreTests: XCTestCase {
    private func makeStore() -> RecordStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testSaveReloadSearchAndDeleteDay() async throws {
        let store = makeStore()
        await store.load()
        XCTAssertTrue(store.isFirstLaunch)
        let day = DayKey(year: 2026, month: 11, day: 25)
        try store.save(day: day, items: [RecordItem(kind: .word, value: "살구잼"), RecordItem(kind: .place, value: "연남동")])

        XCTAssertEqual(store.search("장소").map(\.item.value), ["연남동"])
        XCTAssertEqual(store.search("11.25").count, 2)
        XCTAssertEqual(store.search("남극").count, 0)

        let removed = try store.deleteDay(day)
        XCTAssertTrue(store.isEmpty)
        try store.restoreDay(day, items: removed)
        XCTAssertEqual(store.items(on: day).map(\.value), ["살구잼", "연남동"])
    }

    func testFailedWriteKeepsPreviousState() async throws {
        let store = makeStore()
        await store.load()
        let day = DayKey.today
        try store.save(day: day, items: [RecordItem(kind: .word, value: "귤")])
        store.simulateWriteFailure = true
        XCTAssertThrowsError(try store.save(day: day, items: []))
        XCTAssertEqual(store.items(on: day).map(\.value), ["귤"])
    }
}

@MainActor
final class SampleRecordsTests: XCTestCase {
    /// The shared sample file loads and every fragment follows the input rules.
    func testSampleRecordsAreValid() throws {
        let data = try Data(contentsOf: try SampleRecords.url(bundle: Bundle(for: RecordStore.self)))
        let archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: data)
        XCTAssertEqual(archive.days.count, 24)
        for day in archive.days {
            for item in day.items {
                XCTAssertEqual(ItemValidator.normalize(item.kind, item.value), .value(item.value), "\(day.date.string) \(item.value)")
            }
        }
        let october = try XCTUnwrap(archive.days.first { $0.date == DayKey(year: 2026, month: 10, day: 1) })
        XCTAssertEqual(MonthCellPreview.fragments(october.items).overflow, "+2")
    }
}
