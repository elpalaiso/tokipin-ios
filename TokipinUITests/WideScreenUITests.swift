import XCTest

/// UX v0.4 on an iPad simulator, driven through the real UI (no host access): two panes, the editor
/// in the day pane, typing with hardware-keyboard events, rotation while typing, and the sample
/// tour's last question as a bottom panel. Screenshots are attached to the result bundle.
/// Split View and stylus input cannot be driven from XCUITest and are not covered here.
final class WideScreenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad only") }
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
    }

    private func launch(_ arguments: [String] = ["-uiTestRangeFixture"]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var window: CGRect { app.windows.firstMatch.frame }
    private var today: XCUIElement { app.buttons["오늘"].firstMatch }
    private var add: XCUIElement { app.buttons["기록 추가"].firstMatch }
    private var field: XCUIElement { app.textFields.firstMatch }

    private func hasFocus(_ element: XCUIElement) -> Bool { (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }

    func testTwoPanesSideBySideInPortraitAndLandscape() {
        launch()
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        // 오늘 sits in the left (calendar) pane, + in the right (day) pane.
        XCTAssertLessThan(today.frame.midX, window.midX)
        XCTAssertGreaterThan(add.frame.midX, window.midX)
        shot("portrait two panes")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertLessThan(today.frame.midX, window.midX)
        XCTAssertGreaterThan(add.frame.midX, window.midX)
        shot("landscape two panes")
    }

    func testEditorOpensInTheDayPaneAndKeepsTypingThroughRotation() {
        launch()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // The editor takes the day pane only.
        XCTAssertGreaterThanOrEqual(field.frame.minX, window.midX - 1)
        if !hasFocus(field) { field.tap() }
        // Hardware-keyboard events (digits are the same on every layout); the left arrow moves the caret.
        for key in ["1", "2", "3"] { field.typeKey(key, modifierFlags: []) }
        field.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: [])
        field.typeKey("4", modifierFlags: [])
        XCTAssertEqual(field.value as? String, "1243")
        shot("editor in the day pane")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        XCTAssertTrue(hasFocus(field), "the field kept focus through rotation")
        field.typeKey("5", modifierFlags: [])
        XCTAssertEqual(field.value as? String, "12453", "text and caret kept through rotation")
        shot("editor after rotation")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        field.typeKey("6", modifierFlags: [])
        XCTAssertEqual(field.value as? String, "124563")
    }

    /// §5: rotating while Hangul is being composed neither drops nor doubles what was typed.
    /// (Whether composition continues is up to the keyboard, so only the letters are checked.)
    func testHangulBeingComposedSurvivesRotation() throws {
        launch()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if !hasFocus(field) { field.tap() }
        // The simulator's hardware layout follows its Korean input source: g k s = 한.
        for key in ["g", "k", "s"] { field.typeKey(key, modifierFlags: []) }
        let typed = field.value as? String ?? ""
        guard typed == "한" else { throw XCTSkip("no Korean hardware layout here (got \(typed))") }
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        let after = field.value as? String ?? ""
        XCTAssertEqual(after.filter { $0 == "한" }.count, 1, "composed text kept once: \(after)")
        shot("hangul after rotation")
    }

    func testSearchTypesWithHardwareKeys() {
        launch()
        let search = app.buttons["기록 검색"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertLessThan(search.frame.midX, window.midX, "search lives in the calendar pane")
        search.tap()
        let box = app.textFields.firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        XCTAssertLessThan(box.frame.maxX, window.midX + 1, "the search list takes the calendar pane")
        for key in ["2", "0"] { box.typeKey(key, modifierFlags: []) }
        XCTAssertEqual(box.value as? String, "20")
        shot("search in the calendar pane")
    }

    func testTourLastQuestionIsABottomPanelWithinTheColumn() {
        launch(["-uiTestFreshInstall"])
        sleep(6)
        shot("fresh install")
        let start = app.buttons["trial.start"]
        let next = app.buttons["trial.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15) || start.waitForExistence(timeout: 1))
        // Leave the guide, then ask to start: the last question.
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["입력 안내 닫기", "탐색 안내 닫기"])).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let keepExploring = app.buttons["계속 둘러보기"].firstMatch
        XCTAssertTrue(keepExploring.waitForExistence(timeout: 5))
        shot("tour leave-guide panel")
        keepExploring.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let confirm = app.buttons["trial.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        sleep(1)
        shot("tour last question")
        XCTAssertLessThanOrEqual(confirm.frame.width, 640)
        XCTAssertGreaterThan(confirm.frame.midY, window.height * 0.6, "the panel sits at the bottom")
        XCTAssertEqual(confirm.frame.midX, window.midX, accuracy: 2, "centred in the column")
    }
}
