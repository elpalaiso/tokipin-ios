import XCTest
import SwiftUI
import UIKit
@testable import Tokipin

/// UX v0.4 §5 on today's single-column screens: rotating or resizing the window changes only the
/// layout. The editor keeps the same text field instance, its text, caret and keyboard focus, and
/// navigation state stays as it was. The window is resized directly to the sizes a rotation or
/// Split View gives (the test host cannot turn the simulator). Runs on iPad (iPhone is portrait-only).
@MainActor
final class WindowChangeTests: XCTestCase {
    private var window: UIWindow!
    private var previousRoot: UIViewController?
    private var previousFrame: CGRect = .zero

    override func setUp() async throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad rotates; iPhone is portrait-only") }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow } ?? scene.windows.first)
        previousRoot = window.rootViewController
        previousFrame = window.frame
    }

    override func tearDown() async throws {
        if let window {
            window.rootViewController = previousRoot
            window.frame = previousFrame
        }
    }

    private func makeEnvironment() async throws -> (RecordStore, AppModel, UsageAnalytics) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: directory, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.save(day: DayKey(year: 2026, month: 11, day: 25), items: [RecordItem(kind: .word, value: "살구잼")])
        let usage = UsageAnalytics(directory: directory.appendingPathComponent("usage"), client: UsageAnalyticsClient(
            available: false, setEnabled: { _ in }, recordSave: {}))
        return (store, AppModel(), usage)
    }

    private func host<V: View>(_ view: V) {
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
    }

    /// Same window, new size: what a rotation, Split View or Stage Manager resize does to the app.
    private func resize(width: CGFloat, height: CGFloat) async {
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.layoutIfNeeded()
        try? await Task.sleep(for: .seconds(1))
    }

    private func wait(_ seconds: Double = 0.8) async { try? await Task.sleep(for: .seconds(seconds)) }

    private func inputFields(in view: UIView) -> [ComposerField.InputField] {
        ((view as? ComposerField.InputField).map { [$0] } ?? []) + view.subviews.flatMap(inputFields)
    }

    func testEditorKeepsFieldTextCaretAndFocusThroughWindowResizes() async throws {
        let (store, app, usage) = try await makeEnvironment()
        let day = DayKey(year: 2026, month: 11, day: 27)
        host(EditorView(day: day, focusItem: nil)
            .environment(store).environment(app).environment(usage))
        await wait(1.2)
        let field = try XCTUnwrap(inputFields(in: window).first)
        if !field.isFirstResponder { field.becomeFirstResponder() }
        field.insertText("봄바람")
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 1))
        field.selectedTextRange = field.textRange(from: caret, to: caret)
        await wait()
        let portrait = window.bounds.size

        await resize(width: portrait.height, height: portrait.width)   // landscape
        XCTAssertEqual(window.bounds.width, portrait.height)
        let after = try XCTUnwrap(inputFields(in: window).first)
        XCTAssertTrue(after === field, "the editor's field was rebuilt")
        XCTAssertEqual(after.text, "봄바람")
        XCTAssertEqual(after.offset(from: after.beginningOfDocument, to: after.selectedTextRange!.start), 1)
        XCTAssertTrue(after.isFirstResponder)
        XCTAssertEqual(store.draft(for: day)?.raw, "봄바람")

        // Wider than one column: the editor stays centred at 640pt.
        XCTAssertLessThanOrEqual(after.window!.convert(after.bounds, from: after).width, ContentColumn.maxWidth)

        await resize(width: 500, height: portrait.width)                // Split View, narrow
        XCTAssertTrue(inputFields(in: window).first === field)
        XCTAssertTrue(field.isFirstResponder)

        await resize(width: portrait.width, height: portrait.height)
        let back = try XCTUnwrap(inputFields(in: window).first)
        XCTAssertTrue(back === field)
        XCTAssertEqual(back.offset(from: back.beginningOfDocument, to: back.selectedTextRange!.start), 1)
        XCTAssertTrue(back.isFirstResponder)
    }

    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }

    func testSearchFieldKeepsInstanceTextAndFocusThroughWindowResizes() async throws {
        let (store, app, usage) = try await makeEnvironment()
        app.isSearching = true
        host(ExploreView().environment(store).environment(app).environment(usage))
        await wait(1.2)
        let field = try XCTUnwrap(views(UITextField.self, in: window).first)
        if !field.isFirstResponder { field.becomeFirstResponder() }
        field.insertText("살구")
        await wait()
        XCTAssertEqual(app.searchQuery, "살구")
        let portrait = window.bounds.size
        for size in [CGSize(width: portrait.height, height: portrait.width), CGSize(width: 500, height: portrait.height), portrait] {
            await resize(width: size.width, height: size.height)
            let now = try XCTUnwrap(views(UITextField.self, in: window).first)
            XCTAssertTrue(now === field, "the search field was rebuilt at \(size)")
            XCTAssertEqual(now.text, "살구")
            XCTAssertTrue(now.isFirstResponder)
        }
        XCTAssertTrue(app.isSearching)
    }

    func testMonthScrollPositionSurvivesWindowResizes() async throws {
        let (store, app, usage) = try await makeEnvironment()
        // A year of recorded months so the month view has somewhere to scroll.
        for month in 1...12 { try store.save(day: DayKey(year: 2025, month: month, day: 10), items: [RecordItem(kind: .word, value: "달\(month)")]) }
        app.setLevel(.month, haptic: false)
        host(ExploreView().environment(store).environment(app).environment(usage))
        await wait(1.2)
        let scroll = try XCTUnwrap(views(UIScrollView.self, in: window).max { $0.contentSize.height < $1.contentSize.height })
        scroll.setContentOffset(CGPoint(x: 0, y: max(scroll.contentOffset.y - 1500, 0)), animated: false)
        await wait()
        let offset = scroll.contentOffset.y
        let portrait = window.bounds.size
        // Landscape keeps the same 640pt column, so the same months sit at the same offset.
        await resize(width: portrait.height, height: portrait.width)
        let now = try XCTUnwrap(views(UIScrollView.self, in: window).max { $0.contentSize.height < $1.contentSize.height })
        XCTAssertTrue(now === scroll, "the month list was rebuilt")
        XCTAssertEqual(now.contentOffset.y, offset, accuracy: 1)
        await resize(width: portrait.width, height: portrait.height)
        XCTAssertEqual(now.contentOffset.y, offset, accuracy: 1)
        XCTAssertEqual(app.level, .month)
    }

    /// The real presentation path: RootView's full-screen cover, opened with openEditor(for:).
    func testEditorOpenedFromRootViewKeepsItsFieldThroughWindowResizes() async throws {
        let (store, app, usage) = try await makeEnvironment()
        host(RootView().environment(store).environment(app).environment(usage))
        await wait(1.5)
        let day = DayKey(year: 2026, month: 11, day: 27)
        app.openEditor(for: day)
        await wait(1.5)
        let field = try XCTUnwrap(inputFields(in: window).first)
        if !field.isFirstResponder { field.becomeFirstResponder() }
        field.insertText("귤")
        await wait()
        let portrait = window.bounds.size
        for size in [CGSize(width: portrait.height, height: portrait.width), CGSize(width: 500, height: portrait.height), portrait] {
            await resize(width: size.width, height: size.height)
            let now = try XCTUnwrap(inputFields(in: window).first)
            XCTAssertTrue(now === field, "the editor's field was rebuilt at \(size)")
            XCTAssertEqual(now.text, "귤")
            XCTAssertTrue(now.isFirstResponder)
        }
        XCTAssertEqual(app.editorDay, day)
    }

    /// UX v0.4: two panes on a wide window, one column when narrowed, and back. The editor is a
    /// layer of the pane container, so the same field keeps text, caret and focus throughout.
    func testEditorKeepsItsFieldBetweenTwoPanesAndOneColumn() async throws {
        let (store, app, usage) = try await makeEnvironment()
        host(RootView().environment(store).environment(app).environment(usage))
        await wait(1.5)
        XCTAssertTrue(app.twoPane, "a 13-inch iPad window shows two panes")
        let day = DayKey(year: 2026, month: 11, day: 27)
        app.openEditor(for: day)
        await wait(1.2)
        let field = try XCTUnwrap(inputFields(in: window).first)
        if !field.isFirstResponder { field.becomeFirstResponder() }
        field.insertText("봄바람")
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 1))
        field.selectedTextRange = field.textRange(from: caret, to: caret)
        await wait()
        // The editor sits in the day pane: narrower than the window.
        XCTAssertLessThanOrEqual(field.window!.convert(field.bounds, from: field).width, Adaptive.paneMaxWidth)
        let full = window.bounds.size
        for size in [CGSize(width: 500, height: full.height), full] {
            await resize(width: size.width, height: size.height)
            XCTAssertEqual(app.twoPane, size.width >= Adaptive.twoPaneMinWidth)
            let now = try XCTUnwrap(inputFields(in: window).first)
            XCTAssertTrue(now === field, "the editor's field was rebuilt at \(size)")
            XCTAssertEqual(now.text, "봄바람")
            XCTAssertEqual(now.offset(from: now.beginningOfDocument, to: now.selectedTextRange!.start), 1)
            XCTAssertTrue(now.isFirstResponder)
        }
    }

    /// UX v0.4 §4: a date tapped in the calendar pane opens in the day pane; the calendar keeps its
    /// level; one tick, none for the date already shown; back goes up from the calendar's level.
    func testTwoPaneNavigationKeepsTheCalendarLevel() async throws {
        let (store, app, usage) = try await makeEnvironment()
        var ticks = 0
        app.hapticSink = { ticks += 1 }
        app.hapticsEnabled = { true }
        host(RootView().environment(store).environment(app).environment(usage))
        await wait(1.5)
        XCTAssertTrue(app.twoPane)
        app.setLevel(.month)
        ticks = 0
        app.openDay(DayKey(year: 2026, month: 11, day: 12))
        XCTAssertEqual(app.level, .day)
        XCTAssertEqual(app.calendarLevel, .month)
        XCTAssertEqual(ticks, 1)
        app.openDay(DayKey(year: 2026, month: 11, day: 12))
        XCTAssertEqual(ticks, 1, "the date already shown")
        app.setLevel(.month)
        XCTAssertEqual(ticks, 1, "the level the calendar already shows")
        app.goToday()
        XCTAssertEqual(ticks, 1, "오늘 is silent")
    }

    /// Split View ⅓ cannot be driven from tests; this is the nearest: the window narrowed to a
    /// third (375pt) with the compact size class Split View gives, while editing, and back.
    func testEditorKeepsItsFieldThroughACompactThirdWidthAndBack() async throws {
        let (store, app, usage) = try await makeEnvironment()
        host(RootView().environment(store).environment(app).environment(usage))
        await wait(1.5)
        app.openEditor(for: DayKey(year: 2026, month: 11, day: 27))
        await wait(1.2)
        let field = try XCTUnwrap(inputFields(in: window).first)
        if !field.isFirstResponder { field.becomeFirstResponder() }
        field.insertText("귤잼")
        await wait()
        let full = window.bounds.size
        let root = try XCTUnwrap(window.rootViewController)
        root.traitOverrides.horizontalSizeClass = .compact
        await resize(width: 375, height: full.height)
        XCTAssertEqual(root.traitCollection.horizontalSizeClass, .compact)
        XCTAssertFalse(app.twoPane)
        var now = try XCTUnwrap(inputFields(in: window).first)
        XCTAssertTrue(now === field)
        XCTAssertEqual(now.text, "귤잼")
        XCTAssertTrue(now.isFirstResponder)
        root.traitOverrides.horizontalSizeClass = .regular
        await resize(width: full.width, height: full.height)
        XCTAssertTrue(app.twoPane)
        now = try XCTUnwrap(inputFields(in: window).first)
        XCTAssertTrue(now === field)
        XCTAssertEqual(now.text, "귤잼")
        XCTAssertTrue(now.isFirstResponder)
    }
}
