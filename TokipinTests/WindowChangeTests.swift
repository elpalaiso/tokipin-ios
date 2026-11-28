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

    func testExploreAndSearchStateSurviveWindowResizes() async throws {
        let (store, app, usage) = try await makeEnvironment()
        let day = DayKey(year: 2026, month: 11, day: 25)
        app.openDay(day)
        app.isSearching = true
        app.searchQuery = "살구"
        host(ExploreView().environment(store).environment(app).environment(usage))
        await wait(1.2)
        let portrait = window.bounds.size
        await resize(width: portrait.height, height: portrait.width)
        XCTAssertTrue(app.isSearching)
        XCTAssertEqual(app.searchQuery, "살구")
        XCTAssertEqual(app.level, .day)
        XCTAssertEqual(app.selectedDay, day)
        await resize(width: portrait.width, height: portrait.height)
        XCTAssertEqual(app.level, .day)
        XCTAssertEqual(app.selectedDay, day)
    }
}
