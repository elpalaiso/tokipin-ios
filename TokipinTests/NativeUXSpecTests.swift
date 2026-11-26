import CryptoKit
import XCTest
@testable import Tokipin

/// Runs the shared cases of "Tokipin Native UX v0.1" against the iOS rules.
///
/// The spec has a single copy, shared with Android, at `../tokipin/native-spec/v0.1/`
/// next to this repository. It is pinned by SHA-256 so both apps test the same version.
@MainActor
final class NativeUXSpecTests: XCTestCase {
    static let pinnedSHA256 = "33c5f8d64e76b345fbc49ad7a76fc5ac5cc6556b6f0a7db061bfb2540e37c452"

    static var specURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // TokipinTests
            .deletingLastPathComponent()      // tokipin-ios
            .deletingLastPathComponent()      // parent folder
            .appendingPathComponent("tokipin/native-spec/v0.1/Tokipin-Native-UX-v0.1.json")
    }

    private static var cachedCases: [[String: Any]]?

    private func cases(_ group: String) throws -> [[String: Any]] {
        if Self.cachedCases == nil {
            let data = try Data(contentsOf: Self.specURL)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, Self.pinnedSHA256, "Shared spec changed; update the pin together with Android.")
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            Self.cachedCases = try XCTUnwrap(json["tests"] as? [[String: Any]])
        }
        let found = Self.cachedCases!.filter { $0["group"] as? String == group }
        XCTAssertFalse(found.isEmpty, "No cases for \(group)")
        return found
    }

    private func given(_ test: [String: Any]) -> [String: Any] { test["given"] as? [String: Any] ?? [:] }
    private func expected(_ test: [String: Any]) -> [String: Any] { test["expected"] as? [String: Any] ?? [:] }
    private func id(_ test: [String: Any]) -> String { test["id"] as? String ?? "?" }
    private func number(_ value: Any?) -> CGFloat { CGFloat((value as? NSNumber)?.doubleValue ?? 0) }

    private func level(_ name: String?) -> ExploreLevel {
        switch name {
        case "year": .year
        case "month": .month
        case "recordedDays": .records
        default: .day
        }
    }

    private func day(_ string: Any?) -> DayKey { DayKey(string: string as? String ?? "")! }

    // MARK: Constants

    func testThresholdsMatchSpec() throws {
        let data = try Data(contentsOf: Self.specURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let swipe = try XCTUnwrap(json["swipe"] as? [String: Any])
        let lock = try XCTUnwrap(swipe["axisLock"] as? [String: Any])
        XCTAssertEqual(InteractionRules.axisLockRatio, number(lock["horizontalWhenAbsDxAtLeastAbsDyTimes"]))
        XCTAssertEqual(InteractionRules.distanceCommitFraction, number(swipe["distanceCommitFractionOfW"]))
        XCTAssertEqual(InteractionRules.flickMinDistanceFraction, number(swipe["flickMinDistanceFractionOfW"]))
        XCTAssertEqual(InteractionRules.flickMinSpeedWidthsPerSecond, number(swipe["flickMinSameDirectionSpeedInWidthsPerSecond"]))
        let pinch = try XCTUnwrap(json["pinch"] as? [String: Any])
        XCTAssertEqual(InteractionRules.zoomInScale, number(pinch["enterDetailAtOrAbove"]))
        XCTAssertEqual(InteractionRules.zoomOutScale, number(pinch["enterOverviewAtOrBelow"]), accuracy: 0.0001)
        let settling = try XCTUnwrap(json["settling"] as? [String: Any])
        func within(_ value: Double, _ key: String) {
            let range = (settling[key] as? [NSNumber] ?? []).map(\.doubleValue)
            XCTAssertTrue(value * 1000 >= range[0] && value * 1000 <= range[1], key)
        }
        within(InteractionRules.commitDuration, "commitMs")
        within(InteractionRules.cancelDuration, "cancelMs")
        within(InteractionRules.reduceMotionDuration, "reduceMotionMs")
        XCTAssertFalse(EmojiKeyboard.appSuggestedPalette)
    }

    // MARK: Swipe

    func testSwipeCases() throws {
        for test in try cases("swipe") {
            let g = given(test), e = expected(test)
            let region: InteractionRules.SwipeRegion = g["region"] as? String == "dayWeekRail" ? .weekRail : .dayBody
            let delta = InteractionRules.swipeDelta(
                width: number(g["W"]), dx: number(g["dx"]), dy: number(g["dy"]), vx: number(g["vx"]),
                region: region, systemEdgeBack: g["systemEdgeBack"] as? Bool ?? false,
                osCancel: g["osCancel"] as? Bool ?? false)
            XCTAssertEqual(delta, e["dayDelta"] as? Int, id(test))

            // The committed move goes through the one navigation path: one tick or none.
            let app = AppModel.forTesting()
            var ticks = 0
            app.hapticSink = { ticks += 1 }
            let start = app.selectedDay
            if delta != 0 { app.select(start.adding(days: delta)) }
            XCTAssertEqual(ticks, e["appTicks"] as? Int, id(test))
        }
    }

    // MARK: Pinch

    func testPinchCases() throws {
        for test in try cases("pinch") {
            let g = given(test), e = expected(test)
            let from = level(g["level"] as? String)
            let to = InteractionRules.pinchLevel(from: from, scale: number(g["scaleAtRelease"]),
                                                 osCancel: g["osCancel"] as? Bool ?? false)
            XCTAssertEqual(to, level(e["level"] as? String), id(test))
            let app = AppModel.forTesting(level: from)
            var ticks = 0
            app.hapticSink = { ticks += 1 }
            app.navigate(level: to)
            XCTAssertEqual(ticks, e["appTicks"] as? Int, id(test))
        }
    }

    func testPinchAnchorStaysOnFirstHit() throws {
        for test in try cases("pinchAnchor") {
            let g = given(test), e = expected(test)
            let app = AppModel.forTesting(level: level(g["level"] as? String))
            let first = day(g["firstHit"]), last = day(g["lastHit"])
            app.pinchFrames[.month] = [
                .day(first): CGRect(x: 0, y: 0, width: 50, height: 90),
                .day(last): CGRect(x: 50, y: 0, width: 50, height: 90)
            ]
            // Anchor is resolved once, at the first valid midpoint; later finger movement doesn't re-pick.
            let anchor = try XCTUnwrap(app.pinchTarget(at: CGPoint(x: 25, y: 40), in: .month))
            var ticks = 0
            app.hapticSink = { ticks += 1 }
            let to = InteractionRules.pinchLevel(from: app.level, scale: number(g["scaleAtRelease"]))
            guard case .day(let anchored) = anchor.target else { return XCTFail("anchor should be a day") }
            app.navigate(to: anchored, level: to)
            XCTAssertEqual(app.level, level(e["level"] as? String), id(test))
            XCTAssertEqual(app.selectedDay, day(e["anchor"]), id(test))
            XCTAssertEqual(ticks, e["appTicks"] as? Int, id(test))
        }
    }

    func testPinchGapPicksNearestThenSelected() {
        let app = AppModel.forTesting()
        let selected = app.selectedDay, other = selected.adding(days: 1)
        app.pinchFrames[.month] = [
            .day(other): CGRect(x: 0, y: 0, width: 40, height: 40),
            .day(selected): CGRect(x: 60, y: 0, width: 40, height: 40)
        ]
        XCTAssertEqual(app.pinchTarget(at: CGPoint(x: 45, y: 20), in: .month)?.target, .day(other))
        XCTAssertEqual(app.pinchTarget(at: CGPoint(x: 50, y: 20), in: .month)?.target, .day(selected))
    }

    // MARK: Calendar

    func testCalendarMonthLayout() throws {
        for test in try cases("calendar") {
            let g = given(test), e = expected(test)
            guard let monthString = g["month"] as? String else { continue }
            let parts = monthString.split(separator: "-").compactMap { Int($0) }
            let month = MonthKey(year: parts[0], month: parts[1])
            let firstWeekday = g["firstWeekday"] as? String == "monday" ? 2 : 1
            let column = month.firstDay.column(firstWeekday: firstWeekday)
            XCTAssertEqual(column, e["firstDayColumnIndexZeroBased"] as? Int, id(test))
            let symbols = DayKey.orderedWeekdaySymbols(firstWeekday: firstWeekday)
            XCTAssertEqual(symbols[column], "목", id(test)) // monthLabelAboveWeekday: thursday
            XCTAssertEqual(month.weeks(firstWeekday: firstWeekday).first?[column], 1, id(test))
            if let entries = g["entries"] as? [String] {
                let items = entries.map { RecordItem(kind: ItemValidator.isTime($0) ? .time : .word, value: $0) }
                let preview = MonthCellPreview.fragments(items)
                XCTAssertEqual(preview.shown.map(\.value), e["shown"] as? [String], id(test))
                XCTAssertEqual(preview.overflow, e["overflow"] as? String, id(test))
            }
        }
    }

    func testCalendarScrollYearBoundaryKeepsSelection() throws {
        let test = try XCTUnwrap(try cases("calendar").first { id($0) == "calendar.scrollYearBoundary" })
        let g = given(test), e = expected(test)
        let app = AppModel.forTesting(level: .month, day: day(g["selectedDay"]))
        var ticks = 0
        app.hapticSink = { ticks += 1 }
        app.focusedMonth = MonthKey(year: 2027, month: 1) // what MonthView does while scrolling
        XCTAssertEqual(app.selectedDay, day(e["selectedDay"]))
        XCTAssertEqual(app.focusedMonth.id, e["visibleMonth"] as? String)
        XCTAssertEqual(ticks, e["appTicks"] as? Int)
    }

    func testCalendarBackReturnsToSourceView() throws {
        let test = try XCTUnwrap(try cases("calendar").first { id($0) == "calendar.backPosition" })
        let g = given(test), e = expected(test)
        let app = AppModel.forTesting(level: level(g["fromLevel"] as? String))
        let source = MonthKey(year: 2026, month: 9)
        app.focusedMonth = source // top anchor of the month list; the list view itself stays alive
        app.openDay(day(g["selectedDay"]))
        XCTAssertEqual(app.level, .day)
        app.closeDay()
        XCTAssertEqual(app.level, level(e["level"] as? String))
        XCTAssertEqual(app.selectedDay, day(e["selectedDay"]))
        XCTAssertEqual(app.dayReturnLevel, .month)
    }

    func testCalendarTodayKeepsViewAndScrolls() throws {
        let test = try XCTUnwrap(try cases("calendar").first { id($0) == "calendar.todayWhenSelectedElsewhere" })
        let e = expected(test)
        let app = AppModel.forTesting(level: .year, day: .today)
        app.focusedMonth = MonthKey(year: 2024, month: 1)
        var ticks = 0
        app.hapticSink = { ticks += 1 }
        app.goToday()
        XCTAssertEqual(app.level, level(e["level"] as? String))
        XCTAssertEqual(app.selectedDay, .today)
        XCTAssertEqual(app.focusedMonth.year, DayKey.today.year)
        XCTAssertEqual(app.reveal?.day, .today, "오늘 scrolls even when already selected")
        XCTAssertEqual(ticks, e["appTicks"] as? Int)
    }

    // MARK: Emoji

    func testEmojiCommitCases() throws {
        for test in try cases("emojiCommit") {
            let g = given(test), e = expected(test)
            let raw = try XCTUnwrap(g["raw"] as? String)
            let accepted = e["acceptedText"] as? String ?? ""
            XCTAssertEqual(EmojiRules.filter(raw), accepted, id(test))
            let model = EditorModel(day: .today, items: [], draft: Draft(
                day: .today, items: [], kind: .emoji, raw: raw, editingID: nil, changed: false))
            let appended = model.commitRaw() && !model.items.isEmpty
            XCTAssertEqual(appended, e["appendIfExplicitlyConfirmed"] as? Bool, id(test))
            if appended { XCTAssertEqual(model.items.map(\.value), [accepted], id(test)) }
        }
    }

    func testEmojiCompositionIsLeftAlone() throws {
        for test in try cases("emojiComposition") {
            let e = expected(test)
            // While composing, return is swallowed and nothing is rewritten (ComposerField).
            XCTAssertEqual(ComposerField.shouldCommitOnReturn(preferEmoji: true, isComposing: true), e["append"] as? Bool)
            XCTAssertTrue(ComposerField.shouldPassThroughEdit(preferEmoji: true, isComposing: true))
            XCTAssertEqual(e["rewriteComposition"] as? Bool, false)
        }
    }

    func testEmojiInvalidReplacementKeepsTextAndSelection() throws {
        for test in try cases("emojiSelection") {
            let g = given(test), e = expected(test)
            let range = (g["selectionGraphemeRange"] as? [Int]) ?? [0, 0]
            let edit = EmojiRules.replace(in: g["before"] as? String ?? "", selection: range[0]..<range[1],
                                          with: g["paste"] as? String ?? "")
            let expectedRange = (e["selectionGraphemeRange"] as? [Int]) ?? [0, 0]
            XCTAssertEqual(edit.text, e["text"] as? String, id(test))
            XCTAssertEqual(edit.selection, expectedRange[0]..<expectedRange[1], id(test))
            XCTAssertEqual(edit.changed, e["append"] as? Bool, id(test))
        }
        // Mixed paste keeps its emoji in order and puts the caret after them.
        let mixed = EmojiRules.replace(in: "", selection: 0..<0, with: "비☕🍃")
        XCTAssertEqual(mixed.text, "☕🍃")
        XCTAssertEqual(mixed.selection, 2..<2)
    }

    func testEmojiEditFragments() throws {
        for test in try cases("emojiEdit") {
            let actions = (given(test)["actions"] as? [String]) ?? []
            let model = EditorModel(day: .today, items: [], draft: nil)
            model.setKind(.emoji)
            for action in actions {
                if action.hasPrefix("type ") { model.raw += String(action.dropFirst(5)) }
                if action == "confirm" { model.commitRaw() }
            }
            XCTAssertEqual(model.items.map(\.value), expected(test)["fragmentValues"] as? [String], id(test))
        }
    }

    func testSavedRecordsAreNotRewritten() async throws {
        for test in try cases("migration") {
            let saved = try XCTUnwrap(given(test)["saved"] as? String)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let archive = RecordArchive(days: [.init(date: .today, items: [RecordItem(kind: .emoji, value: saved)], updatedAt: Date())])
            try JSONEncoder.tokipin.encode(archive).write(to: dir.appendingPathComponent("records.json"))
            let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
            await store.load()
            let value = store.items(on: .today).first?.value
            XCTAssertEqual(value, expected(test)["saved"] as? String, id(test))
        }
    }

    func testEmojiKeyboardCapability() throws {
        for test in try cases("capability") where given(test)["platform"] as? String == "iOS" {
            let e = expected(test)
            // With an emoji keyboard enabled we ask for it; without, the current keyboard stays.
            XCTAssertEqual(EmojiKeyboard.preferredIndex(languages: ["ko-KR", "emoji"]), 1)
            XCTAssertNil(EmojiKeyboard.preferredIndex(languages: ["ko-KR", "en-US"]))
            XCTAssertEqual(EmojiKeyboard.appSuggestedPalette, e["appSuggestedPalette"] as? Bool)
            XCTAssertEqual(!EmojiRules.filter("☕").isEmpty, e["acceptEmojiPaste"] as? Bool)
        }
    }

    // MARK: Time

    func testTimeDisplayCases() throws {
        for test in try cases("timeDisplay") {
            let g = given(test), e = expected(test)
            let saved = try XCTUnwrap(g["saved"] as? String)
            let cycle = g["hourCyclePreference"] as? Int ?? 24
            let parts = try XCTUnwrap(TimeRules.displayParts(saved, hourCycle: cycle))
            XCTAssertEqual(parts.hour, e["displayHour"] as? Int, id(test))
            XCTAssertEqual(parts.minute, e["displayMinute"] as? Int, id(test))
            XCTAssertEqual(parts.dayPeriod, e["dayPeriod"] as? String, id(test))
            XCTAssertEqual(saved, e["storedUnchanged"] as? String, id(test))
            // The formatter users see agrees with the parts.
            let shown = TimeRules.display(saved, uses24Hour: cycle == 24)
            XCTAssertTrue(shown.contains(cycle == 24 ? String(format: "%02d:%02d", parts.hour, parts.minute)
                                                       : String(format: "%d:%02d", parts.hour, parts.minute)), "\(id(test)): \(shown)")
        }
        XCTAssertEqual(TimeRules.display("18:45", uses24Hour: false), "오후 6:45")
        XCTAssertEqual(TimeRules.display("18:45", uses24Hour: true), "18:45")
    }

    func testTimeEditCases() throws {
        for test in try cases("timeEdit") {
            let g = given(test), e = expected(test)
            let before = ((g["before"] as? [String]) ?? []).map { RecordItem(kind: .time, value: $0) }
            let model = EditorModel(day: .today, items: before, draft: nil)
            model.setKind(.time)
            var saved: [RecordItem] = before
            for action in (g["actions"] as? [String]) ?? [] {
                switch action {
                case let a where a.hasPrefix("choose ") || a.hasPrefix("select "):
                    model.raw = String(a.split(separator: " ")[1])     // explicit wheel change
                case let a where a.hasPrefix("open "):
                    break                                              // opening the wheel stages nothing
                case "edit":
                    model.edit(model.items[0])
                case "+":
                    model.commitRaw()
                case "cancel":
                    model.cancelPending()
                case "✓":
                    saved = model.itemsForSaving() ?? saved
                default:
                    XCTFail("unknown action \(action)")
                }
            }
            XCTAssertEqual(saved.map(\.value), e["fragmentValues"] as? [String], id(test))
        }
    }

    // MARK: Haptics

    func testHapticCases() throws {
        for test in try cases("haptic") {
            let g = given(test), e = expected(test)
            let events = ((g["eventsFromOneAction"] as? [String]) ?? []).compactMap(InteractionRules.NavigationEvent.init(rawValue:))
            XCTAssertEqual(InteractionRules.ticks(for: events, enabled: g["enabled"] as? Bool ?? true),
                           e["appTicks"] as? Int, id(test))
        }
    }

    func testHapticsThroughTheNavigationPath() {
        let app = AppModel.forTesting(level: .month)
        var ticks = 0
        app.hapticSink = { ticks += 1 }
        app.openDay(app.selectedDay.adding(days: 3))     // date + level in one action
        XCTAssertEqual(ticks, 1)
        app.select(app.selectedDay)                       // reselect
        XCTAssertEqual(ticks, 1)
        app.goToday()                                     // 오늘
        XCTAssertEqual(ticks, 1)
        app.setLevel(.day)                                // already there (level limit)
        XCTAssertEqual(ticks, 1)
        app.hapticsEnabled = { false }
        app.select(app.selectedDay.adding(days: 1))       // haptics off
        XCTAssertEqual(ticks, 1)
    }
}

extension AppModel {
    static func forTesting(level: ExploreLevel = .day, day: DayKey = .today) -> AppModel {
        let app = AppModel()
        app.hapticSink = {}
        app.hapticsEnabled = { true }
        app.navigate(to: day, level: level, haptic: false)
        return app
    }
}
