import SwiftUI
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

    func testTrialUsesThreeYearsOfRealJournalOperationsOnlyInMemory() async throws {
        let personal = await readStore()
        let today = try XCTUnwrap(DayKey(string: "2026-11-27"))
        let tour = SampleTour(today: today)
        let store = tour.store
        XCTAssertTrue(store.isSample)
        XCTAssertGreaterThan(store.records.count, 750)
        XCTAssertEqual(tour.app.editorDay, today)
        XCTAssertFalse(store.items(on: today).isEmpty && store.latestDraft == nil)
        let testItem = RecordItem(kind: .word, value: "only inside sample")
        try store.save(day: today, items: [testItem])
        XCTAssertEqual(store.search("only inside sample").first?.day, today)
        store.updateDraft(Draft(day: today, items: [], kind: .word, raw: "private", changed: true), for: today)
        XCTAssertEqual(store.latestDraft?.raw, "private")
        let removed = try store.deleteDay(today)
        XCTAssertTrue(store.search("only inside sample").isEmpty)
        try store.restoreDay(today, items: removed)
        try store.replaceItem(RecordItem(id: testItem.id, kind: .word, value: "edited"), on: today)
        XCTAssertEqual(store.items(on: today).first?.value, "edited")
        XCTAssertThrowsError(try store.exportData())
        XCTAssertTrue(personal.isEmpty)
        XCTAssertNil(personal.latestDraft)
        XCTAssertTrue(personal.search("only inside sample").isEmpty)
        let archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: personal.exportData())
        XCTAssertTrue(archive.days.isEmpty)
        let relaunched = await readStore()
        XCTAssertTrue(relaunched.needsSampleCalendar(hasUsageChoice: false))
        XCTAssertTrue(SampleTour(today: today).store.search("only inside sample").isEmpty)
    }

    func testChangingTrialHintPreservesActiveComposerAndMarkedText() async throws {
        let probe = ComposerProbe()
        let host = UIHostingController(rootView: ProbeView(probe: probe))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; oldWindow?.makeKeyAndVisible() }
        host.view.layoutIfNeeded()

        let field = try XCTUnwrap(findField(in: host.view))
        field.becomeFirstResponder()
        field.setMarkedText("서울", selectedRange: NSRange(location: 2, length: 0))
        probe.highlighted = false
        try await Task.sleep(for: .milliseconds(60))
        host.view.layoutIfNeeded()
        XCTAssertIdentical(findField(in: host.view), field)
        XCTAssertEqual(field.text, "서울")
        XCTAssertNotNil(field.markedTextRange)
    }

    private func findField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }
        for child in view.subviews {
            if let field = findField(in: child) { return field }
        }
        return nil
    }

    func testNativeGeneratorUsesWebVocabularyForAllLanguages() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "SampleVocabulary", withExtension: "json"))
        let packs = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        XCTAssertEqual(Set(packs.keys), Set(LocalizationTests.languages))
        let tokens = Set(try XCTUnwrap(packs["ko"]).keys)
        XCTAssertEqual(tokens.count, 111)
        XCTAssertTrue(Set(SampleGenerator.words.keys).isSubset(of: tokens))
        for pack in packs.values { XCTAssertEqual(Set(pack.keys), tokens) }
        let day = try XCTUnwrap(DayKey(string: "2026-11-27"))
        let ko = SampleGenerator.items(for: day, vocabulary: try XCTUnwrap(packs["ko"]), starter: true)
        let en = SampleGenerator.items(for: day, vocabulary: try XCTUnwrap(packs["en"]), starter: true)
        XCTAssertEqual(ko.map(\.kind), [.word, .emoji, .place, .time])
        XCTAssertEqual(ko.map(\.id), en.map(\.id))
        XCTAssertNotEqual(ko.first?.value, en.first?.value)
        XCTAssertEqual(ko.last?.value, en.last?.value)
    }

    func testRealNavigationAdvancesTheGuideWithoutSkippingSteps() {
        let tour = SampleTour()
        tour.app.editorDay = nil
        tour.nextInArchive()
        XCTAssertEqual(tour.cue, .dayZoom)
        tour.nextInArchive()
        XCTAssertEqual(tour.app.level, .records)
        tour.changedLevel(from: .day, to: .records)
        let before = tour.app.recordsMonth
        tour.nextInArchive()
        XCTAssertNotEqual(tour.app.recordsMonth, before)
        XCTAssertEqual(tour.cue, .recordsZoom)
        tour.changedRecordsMonth()
        XCTAssertEqual(tour.cue, .recordsZoom)
        tour.nextInArchive()
        tour.changedLevel(from: .records, to: .month)
        tour.nextInArchive()
        XCTAssertEqual(tour.cue, .monthZoom)
        tour.nextInArchive()
        tour.changedLevel(from: .month, to: .year)
        tour.nextInArchive()
        tour.changedLevel(from: .year, to: .month)
        XCTAssertEqual(tour.cue, .pickDay)
        // A menu change or search result is free navigation, not the last guided date tap.
        tour.changedLevel(from: .month, to: .day)
        XCTAssertNil(tour.panel)
        XCTAssertEqual(tour.cue, .daySwipe)
        tour.changedLevel(from: .year, to: .month)
        tour.nextInArchive()
        tour.changedLevel(from: .month, to: .day)
        XCTAssertEqual(tour.panel, .invitation)
        tour.panel = nil
        XCTAssertFalse(tour.guided)
        tour.replay()
        XCTAssertTrue(tour.guided)
        XCTAssertEqual(tour.cue, .daySwipe)
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

@MainActor @Observable private final class ComposerProbe {
    var raw = ""
    var highlighted = true
}

private struct ProbeView: View {
    @Bindable var probe: ComposerProbe

    var body: some View {
        ComposerField(text: $probe.raw, placeholder: "", font: .systemFont(ofSize: 16), preferEmoji: false,
                      isFocused: true, accessibilityLabel: "", onReturn: {})
            .trialHighlight(probe.highlighted)
    }
}
