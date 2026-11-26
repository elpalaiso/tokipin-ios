import XCTest
@testable import Tokipin

/// Daily read/edit flow: reorder, per-day drafts, first save / last delete, empty art layout.
@MainActor
final class DailyEditorTests: XCTestCase {
    private let day = DayKey(year: 2026, month: 11, day: 25)
    private let otherDay = DayKey(year: 2026, month: 11, day: 23)

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func makeStore(_ directory: URL, suite: String) -> RecordStore {
        RecordStore(directory: directory, defaults: UserDefaults(suiteName: suite)!)
    }

    private func items(_ values: [(ItemKind, String)]) -> [RecordItem] {
        values.map { RecordItem(kind: $0.0, value: $0.1) }
    }

    // MARK: Reorder

    func testMoveAcrossKindsMarksChanged() {
        let saved = items([(.word, "살구잼"), (.place, "연남동"), (.time, "16:20"), (.emoji, "🍊")])
        let model = EditorModel(day: day, items: saved, draft: nil)
        XCTAssertFalse(model.changed)
        model.move(saved[3].id, by: -1)   // 🍊 above 16:20
        model.move(saved[3].id, by: -1)   // 🍊 above 연남동
        XCTAssertEqual(model.items.map(\.value), ["살구잼", "🍊", "연남동", "16:20"])
        XCTAssertTrue(model.changed)
        // Out of range is a no-op.
        model.move(saved[0].id, by: -1)
        XCTAssertEqual(model.items.first?.value, "살구잼")
    }

    func testMoveFromOffsetsOnlyChangesWhenOrderDiffers() {
        let saved = items([(.word, "a"), (.word, "b")])
        let model = EditorModel(day: day, items: saved, draft: nil)
        model.move(fromOffsets: [0], toOffset: 1)  // same place
        XCTAssertFalse(model.changed)
        model.move(fromOffsets: [0], toOffset: 2)
        XCTAssertEqual(model.items.map(\.value), ["b", "a"])
        XCTAssertTrue(model.changed)
    }

    func testUndoAfterReorderPutsItemBackWithoutLosingNewOrder() {
        let saved = items([(.word, "귤"), (.place, "서울숲"), (.emoji, "🧣")])
        let model = EditorModel(day: day, items: saved, draft: nil)
        model.move(saved[2].id, by: -1)
        model.move(saved[2].id, by: -1)
        XCTAssertEqual(model.items.map(\.value), ["🧣", "귤", "서울숲"])
        model.delete(ids: [saved[0].id])
        model.undoDelete()
        XCTAssertEqual(model.items.map(\.value), ["🧣", "귤", "서울숲"])
    }

    func testOrderOnlyChangeSurvivesRelaunch() async throws {
        let dir = makeDirectory(), suite = UUID().uuidString
        let store = makeStore(dir, suite: suite)
        await store.load()
        let saved = items([(.word, "살구잼"), (.place, "연남동"), (.emoji, "🍊")])
        try store.save(day: day, items: saved)

        let model = EditorModel(day: day, items: store.items(on: day), draft: nil)
        model.move(saved[1].id, by: -1)
        let toSave = try XCTUnwrap(model.itemsForSaving())
        try store.save(day: day, items: toSave)

        let relaunched = makeStore(dir, suite: suite)
        await relaunched.load()
        XCTAssertEqual(relaunched.items(on: day).map(\.value), ["연남동", "살구잼", "🍊"])
    }

    // MARK: Drafts

    func testDraftsArePerDayAndSurviveRelaunch() async throws {
        let dir = makeDirectory(), suite = UUID().uuidString
        let store = makeStore(dir, suite: suite)
        await store.load()
        let a = Draft(day: day, items: items([(.word, "첫서리")]), kind: .word, raw: "", editingID: nil, changed: true)
        let b = Draft(day: otherDay, items: [], kind: .place, raw: "한강", editingID: nil, changed: false)
        store.updateDraft(a, for: day)
        store.updateDraft(b, for: otherDay)
        // Saving or clearing one day leaves the other's draft alone.
        store.updateDraft(nil, for: day)
        XCTAssertNil(store.draft(for: day))
        XCTAssertEqual(store.draft(for: otherDay)?.raw, "한강")

        let relaunched = makeStore(dir, suite: suite)
        await relaunched.load()
        XCTAssertNil(relaunched.draft(for: day))
        XCTAssertEqual(relaunched.draft(for: otherDay)?.raw, "한강")
        XCTAssertEqual(relaunched.latestDraft?.day, otherDay)
    }

    func testLatestDraftIsTheMostRecentlyTouched() async throws {
        let store = makeStore(makeDirectory(), suite: UUID().uuidString)
        await store.load()
        store.updateDraft(Draft(day: day, items: [], kind: .word, raw: "a", editingID: nil, changed: false), for: day)
        try await Task.sleep(for: .milliseconds(20))
        store.updateDraft(Draft(day: otherDay, items: [], kind: .word, raw: "b", editingID: nil, changed: false), for: otherDay)
        XCTAssertEqual(store.latestDraft?.day, otherDay)
    }

    func testLegacySingleDraftIsMigrated() async throws {
        let dir = makeDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let old = Draft(day: otherDay, items: [], kind: .word, raw: "산책", editingID: nil, changed: false)
        try JSONEncoder.tokipin.encode(old).write(to: dir.appendingPathComponent("draft.json"))
        let store = makeStore(dir, suite: UUID().uuidString)
        await store.load()
        XCTAssertEqual(store.draft(for: otherDay)?.raw, "산책")
    }

    func testDraftMatchingSavedRecordIsDroppedOnLoad() async throws {
        let dir = makeDirectory(), suite = UUID().uuidString
        let store = makeStore(dir, suite: suite)
        await store.load()
        let saved = items([(.word, "산책")])
        try store.save(day: otherDay, items: saved)
        store.updateDraft(Draft(day: otherDay, items: saved, kind: .word, raw: "", editingID: nil, changed: true), for: otherDay)

        let relaunched = makeStore(dir, suite: suite)
        await relaunched.load()
        XCTAssertNil(relaunched.latestDraft, "an already saved draft must not reopen the editor")
    }

    // MARK: First save / last delete

    func testFirstSaveFillsDayAndLastDeleteEmptiesIt() async throws {
        let store = makeStore(makeDirectory(), suite: UUID().uuidString)
        await store.load()
        XCTAssertTrue(store.items(on: otherDay).isEmpty)

        let model = EditorModel(day: otherDay, items: [], draft: nil)
        model.raw = "산책"
        try store.save(day: otherDay, items: try XCTUnwrap(model.itemsForSaving()))
        XCTAssertEqual(store.items(on: otherDay).map(\.value), ["산책"])
        XCTAssertEqual(store.days(in: otherDay.monthKey), [otherDay])

        let editing = EditorModel(day: otherDay, items: store.items(on: otherDay), draft: nil)
        editing.delete(ids: [editing.items[0].id])
        try store.save(day: otherDay, items: try XCTUnwrap(editing.itemsForSaving()))
        XCTAssertTrue(store.items(on: otherDay).isEmpty)
        XCTAssertTrue(store.days(in: otherDay.monthKey).isEmpty)
    }

    // MARK: Empty art

    func testEmptyArtSizeFollowsPageWidth() {
        XCTAssertEqual(EmptyRecordArt.size(forPageWidth: 390), CGSize(width: 172, height: 120))
        XCTAssertEqual(EmptyRecordArt.size(forPageWidth: 440), CGSize(width: 172, height: 120), "capped at 172")
        XCTAssertEqual(EmptyRecordArt.size(forPageWidth: 320), CGSize(width: 141, height: 98))
    }

    func testEmptyArtCentreSitsAt30PercentAndClamps() {
        XCTAssertEqual(EmptyRecordArt.centerY(forHeight: 600, artHeight: 120), 180)
        // Short space: the whole art stays inside.
        let short = EmptyRecordArt.centerY(forHeight: 150, artHeight: 120)
        XCTAssertGreaterThanOrEqual(short - 60, 0)
        XCTAssertLessThanOrEqual(short + 60, 150)
    }

    func testEmptyStateStrings() {
        XCTAssertEqual(EmptyStateText.day, "이날 남긴 기록이 없어요.")
        XCTAssertEqual(EmptyStateText.month(MonthKey(year: 2026, month: 12)), "12월에 남긴 기록이 없어요.")
    }
}
