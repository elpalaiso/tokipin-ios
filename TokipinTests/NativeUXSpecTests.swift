import CryptoKit
import XCTest
@testable import Tokipin

/// Runs the shared cases of "Tokipin Native UX v0.3" (81 kept from v0.2, 1 replaced, 27 new for
/// the date headers and 기록한 날's shown-month list) against the iOS rules.
///
/// The spec has a single copy, shared with Android, at `../tokipin/native-spec/v0.3/`
/// next to this repository. It is pinned by SHA-256 so both apps test the same version.
@MainActor
final class NativeUXSpecTests: XCTestCase {
    static let pinnedSHA256 = "6bddea73872758395ec047089b96a96ba996fa0cdaef11117363347655599512"

    static var specURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // TokipinTests
            .deletingLastPathComponent()      // tokipin-ios
            .deletingLastPathComponent()      // parent folder
            .appendingPathComponent("tokipin/native-spec/v0.3/Tokipin-Native-UX-v0.3.json")
    }

    private static var cachedCases: [[String: Any]]?
    /// Groups this file runs. `capability` cases for Android are filtered inside.
    static let handledGroups: Set<String> = [
        "swipe", "pinch", "pinchAnchor", "calendar", "emojiCommit", "emojiComposition", "emojiSelection",
        "emojiEdit", "migration", "capability", "timeDisplay", "timeEdit", "haptic", "recordedMonths",
        "visibleMonthIndex", "monthYearHints", "dateHeaders"
    ]

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

    // MARK: Coverage

    /// Every case in the pinned file belongs to a group with a runner here (109 cases, 108 on iOS).
    func testEveryCaseHasARunner() throws {
        _ = try cases("swipe")
        let all = Self.cachedCases!
        XCTAssertEqual(all.count, 109)
        let groups = Set(all.compactMap { $0["group"] as? String })
        XCTAssertEqual(groups.subtracting(Self.handledGroups), [], "Unhandled groups")
        let androidOnly = all.filter { ($0["given"] as? [String: Any])?["platform"] as? String == "Android" }
        XCTAssertEqual(androidOnly.map { $0["id"] as? String }, ["emoji.externalIme"])
        XCTAssertEqual(all.filter { $0["group"] as? String == "recordedMonths" }.count, 23)
        XCTAssertEqual(all.filter { $0["group"] as? String == "visibleMonthIndex" }.count, 15)
        XCTAssertEqual(all.filter { $0["group"] as? String == "monthYearHints" }.count, 7)
        XCTAssertEqual(all.filter { $0["group"] as? String == "dateHeaders" }.count, 5)
    }

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
            // Word/place go back to a letter keyboard, preferring the one used last.
            XCTAssertEqual(EmojiKeyboard.textIndex(languages: ["en-US", "emoji", "ko-KR"], lastUsed: "ko-KR"), 2)
            XCTAssertEqual(EmojiKeyboard.textIndex(languages: ["emoji", "en-US"], lastUsed: nil), 1)
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

    // MARK: 기록한 날 months (v0.2)

    private func month(_ string: Any?) -> MonthKey {
        let parts = (string as? String ?? "").split(separator: "-").compactMap { Int($0) }
        return MonthKey(year: parts[0], month: parts[1])
    }

    private func store(with dates: [String]) async throws -> RecordStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        for date in dates { try store.save(day: day(date), items: [RecordItem(kind: .word, value: "기록")]) }
        return store
    }

    /// The shared "달력 범위 예시" (512 days), used by `fixture: calendarRangeArchive`.
    private static var archiveDays: [DayKey]?
    private func archiveDays() throws -> [DayKey] {
        if let days = Self.archiveDays { return days }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tokipin/DebugFixtures/calendar-range-records.json")
        let archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: Data(contentsOf: url))
        let days = archive.days.filter { !$0.items.isEmpty }.map(\.date)
        Self.archiveDays = days
        return days
    }

    /// Saved days for a case: the shared archive or the listed dates.
    private func recordedDays(_ g: [String: Any]) throws -> [DayKey] {
        if g["fixture"] as? String == "calendarRangeArchive" { return try archiveDays() }
        return ((g["availableRecordDates"] as? [String]) ?? []).map(day)
    }

    private func today(_ g: [String: Any]) -> DayKey { g["deviceToday"].map(day) ?? DayKey(year: 2026, month: 11, day: 26) }

    func testRecordedMonthsCases() async throws {
        var ran: [String] = []
        for test in try cases("recordedMonths") {
            let g = given(test), e = expected(test), name = id(test)
            let deviceToday = today(g)
            let start = g["committedMonth"].map(month) ?? deviceToday.monthKey
            let selected = g["selectedDay"].map(day) ?? start.firstDay
            let app = AppModel.forTesting(level: level(g["level"] as? String ?? "recordedDays"), day: selected)
            app.today = deviceToday
            app.commitRecordsMonth(start, haptic: false)
            var ticks = 0
            app.hapticSink = { ticks += 1 }
            if let enabled = g["appHapticsEnabled"] as? Bool { app.hapticsEnabled = { enabled } }
            let data = try await store(with: (g["availableRecordDates"] as? [String]) ?? [])
            let months = RecordedMonths.visible(recordedDays: data.records.keys, today: deviceToday)
            var preview: MonthKey?
            var monthCommits = 0

            switch g["action"] as? String ?? (g["actions"] as? [String])?.first {
            case "bodySwipeRelease", "verticalDragAtBottom":
                let delta = InteractionRules.swipeDelta(
                    width: number(g["W"]), dx: number(g["dx"]), dy: number(g["dy"]), vx: number(g["vx"]),
                    region: .recordsBody, systemEdgeBack: g["systemEdgeBack"] as? Bool ?? false,
                    osCancel: g["osCancel"] as? Bool ?? false)
                XCTAssertLessThanOrEqual(abs(delta), 1, "\(name): one page per swipe")
                if delta != 0, let next = RecordedMonths.neighbour(of: app.recordsMonth, step: delta, in: months) {
                    app.commitRecordsMonth(next)
                }
            case "bodyDrag":
                let fraction = number(g["dragFraction"])
                preview = abs(fraction) >= 0.5 ? RecordedMonths.neighbour(of: start, step: fraction > 0 ? 1 : -1, in: months) : start
                XCTAssertEqual(number(e["bodyProgress"]), fraction)
                XCTAssertEqual(number(e["railProgress"]), fraction)
                XCTAssertEqual(preview, month(g["neighborMonth"]), name)
            case "renderRail":
                let window = RecordedMonths.window(committed: start, sideSlots: g["sideSlotsInThisFixture"] as? Int ?? 2, in: months)
                XCTAssertEqual(window.map { $0?.id }, (e["visibleMonthKeys"] as? [String])?.map(Optional.init), name)
                XCTAssertEqual(window.map { $0?.month }, (e["visibleMonthNumbers"] as? [Int])?.map(Optional.init), name)
            case "tapRailMonth":
                app.commitRecordsMonth(month(g["tappedMonth"]))
                if let spatial = e["spatialTransition"] as? Bool {
                    XCTAssertEqual(spatial, !(g["reduceMotion"] as? Bool ?? false), name)
                }
            case "railCoast":
                preview = month(g["nearestCandidate"])       // highlighted only; nothing committed mid-coast
            case "railSettle":
                let steps = Int(number(g["projectedSlotOffsetAtRest"]).rounded())
                let index = months.firstIndex(of: start)! + steps
                app.commitRecordsMonth(months[min(max(index, 0), months.count - 1)])
            case "cancelRail":
                break
            case "today":
                app.goToday(deviceToday)
            case "openDay":
                app.openDay(day(g["openedDay"]))
                XCTAssertEqual(app.level, .day, name)
                app.closeDay()
            case "beginBodyDrag":
                app.isPinching = true
                let delta = InteractionRules.swipeDelta(width: 390, dx: -120, dy: 0, vx: -500,
                                                         region: .recordsBody, osCancel: app.isPinching)
                if delta != 0 { monthCommits += 1 }
                app.isPinching = false
                let to = InteractionRules.pinchLevel(from: app.level, scale: number(g["scaleAtRelease"]))
                app.navigate(to: day(g["firstHit"]), level: to)
                XCTAssertEqual(monthCommits, e["monthCommitCount"] as? Int, name)
                XCTAssertEqual(app.selectedDay, day(e["anchor"]), name)
            default:
                XCTFail("Unknown action in \(name)")
            }

            if let level = e["level"] as? String { XCTAssertEqual(app.level, self.level(level), name) }
            if let committed = e["committedMonth"] { XCTAssertEqual(app.recordsMonth, month(committed), name) }
            if let centred = e["centeredMonth"] { XCTAssertEqual(app.recordsMonth, month(centred), "\(name): rail centre = committed") }
            if let year = e["headerYear"] as? Int { XCTAssertEqual(DateHeader.year(app.recordsMonth), String(year), name) }
            if let previewMonth = e["previewMonth"] { XCTAssertEqual(preview, month(previewMonth), name) }
            if let selectedDay = e["selectedDay"] { XCTAssertEqual(app.selectedDay, day(selectedDay), name) }
            if let cards = e["visibleCardDates"] as? [String] {
                XCTAssertEqual(data.days(in: app.recordsMonth).map(\.string), cards, name)
            }
            if let empty = e["showMonthEmptyState"] as? Bool {
                XCTAssertEqual(data.days(in: app.recordsMonth).isEmpty, empty, name)
            }
            if let expectedTicks = e["appTicks"] as? Int { XCTAssertEqual(ticks, expectedTicks, "\(name) ticks") }
            ran.append(name)
        }
        XCTAssertEqual(ran.count, 23)
    }

    // MARK: Shown-month list (v0.3)

    func testVisibleMonthIndexCases() throws {
        var ran = 0
        for test in try cases("visibleMonthIndex") {
            let g = given(test), e = expected(test), name = id(test)
            var deviceToday = today(g)
            var days = Set(try recordedDays(g))
            var months = RecordedMonths.visible(recordedDays: days, today: deviceToday)
            // Drafts never add a month.
            for draft in ((g["draftOnlyDates"] as? [String]) ?? []).map(day) where draft.monthKey != deviceToday.monthKey {
                XCTAssertFalse(months.contains(draft.monthKey), name)
            }
            let selected = g["selectedDay"].map(day) ?? deviceToday
            let app = AppModel.forTesting(level: .records, day: selected)
            app.today = deviceToday
            if let committed = g["committedMonth"] { app.commitRecordsMonth(month(committed), haptic: false) }
            var ticks = 0
            app.hapticSink = { ticks += 1 }
            let reconcile = {
                let resolved = RecordedMonths.resolve(app.recordsMonth, in: months)
                if resolved != app.recordsMonth { app.commitRecordsMonth(resolved, haptic: false) }
            }

            switch g["action"] as? String {
            case "buildVisibleMonths":
                break
            case "bodySlotStep":
                if let next = RecordedMonths.neighbour(of: app.recordsMonth, step: g["direction"] as? Int ?? 0, in: months) {
                    app.commitRecordsMonth(next)
                }
            case "resolveAnchor":
                // Entering 기록한 날 from an empty past month (e.g. a pinch from 월간).
                app.navigate(to: selected, level: .month, haptic: false)
                app.navigate(level: .records, haptic: false)
                app.commitRecordsMonth(month(g["requestedMonth"]), haptic: false)
                reconcile()
                XCTAssertEqual(ticks, e["monthTicks"] as? Int ?? 0, name)
            case "refresh":
                for removed in (g["remove"] as? [String]) ?? [] { days.remove(day(removed)) }
                for inserted in (g["insert"] as? [String]) ?? [] { days.insert(day(inserted)) }
                if let newToday = g["newDeviceToday"] { deviceToday = day(newToday); app.today = deviceToday }
                months = RecordedMonths.visible(recordedDays: days, today: deviceToday)
                reconcile()
            case "cancelBodyDrag":
                // The preview showed another year; releasing without a commit leaves everything.
                XCTAssertEqual(RecordedMonths.neighbour(of: app.recordsMonth, step: 1, in: months), month(g["previewMonth"]), name)
            default:
                XCTFail("Unknown action in \(name)")
            }

            if let list = e["visibleMonths"] as? [String] { XCTAssertEqual(months.map(\.id), list, name) }
            if let committed = e["committedMonth"] { XCTAssertEqual(app.recordsMonth, month(committed), name) }
            if let selectedDay = e["selectedDay"] { XCTAssertEqual(app.selectedDay, day(selectedDay), name) }
            if let year = e["headerYear"] as? Int { XCTAssertEqual(DateHeader.year(app.recordsMonth), String(year), name) }
            if let empty = e["showMonthEmptyState"] as? Bool {
                XCTAssertEqual(!days.contains { $0.monthKey == app.recordsMonth }, empty, name)
            }
            if let expectedTicks = e["appTicks"] as? Int { XCTAssertEqual(ticks, expectedTicks, "\(name) ticks") }
            ran += 1
        }
        XCTAssertEqual(ran, 15)
    }

    func testMonthYearHintCases() throws {
        var ran = 0
        for test in try cases("monthYearHints") {
            let g = given(test), e = expected(test), name = id(test)
            let months = RecordedMonths.visible(recordedDays: try recordedDays(g), today: today(g))
            let app = AppModel.forTesting(level: .records, day: today(g))
            app.today = today(g)
            app.commitRecordsMonth(month(g["committedMonth"]), haptic: false)
            var ticks = 0
            app.hapticSink = { ticks += 1 }

            switch g["action"] as? String {
            case "renderHints":
                let window = RecordedMonths.window(committed: app.recordsMonth, sideSlots: g["sideSlotsInThisFixture"] as? Int ?? 2, in: months)
                let hints = RecordedMonths.hints(window: window, committed: app.recordsMonth)
                XCTAssertEqual(window.map { $0?.id }, (e["visibleMonthKeys"] as? [Any])?.map { $0 as? String }, name)
                XCTAssertEqual(window.map { $0?.month }, (e["visibleMonthNumbers"] as? [Any])?.map { $0 as? Int }, name)
                XCTAssertEqual(hints, (e["hintsBySlot"] as? [Any])?.map { $0 as? String }, name)
            case "inspectRailAccessibility":
                let target = month(g["targetMonth"])
                let value = e["monthValue"] as? [String: Int]
                XCTAssertEqual(target.year, value?["year"]); XCTAssertEqual(target.month, value?["month"])
                XCTAssertEqual(target.spokenLabel, "2023년 4월", name)
                XCTAssertEqual(target == app.recordsMonth, e["isSelected"] as? Bool, name)
                // MonthRail merges the hint into the slot's single accessibility element.
                XCTAssertEqual(e["hintIsSeparateAccessibleElement"] as? Bool, false)
            case "tapRailMonth":
                app.commitRecordsMonth(month(g["tappedMonth"]))
                // Rail and hint: fixed 14pt hint line and fixed capsule frame, so nothing shifts.
                XCTAssertEqual(number(e["baselineShift"]), 0); XCTAssertEqual(number(e["capsuleCenterShift"]), 0)
                XCTAssertEqual(e["spatialTransition"] as? Bool, !(g["reduceMotion"] as? Bool ?? false), name)
            default:
                XCTFail("Unknown action in \(name)")
            }
            if let committed = e["centeredMonth"] ?? e["committedMonth"] { XCTAssertEqual(app.recordsMonth, month(committed), name) }
            if let year = e["headerYear"] as? Int { XCTAssertEqual(DateHeader.year(app.recordsMonth), String(year), name) }
            if let expectedTicks = e["appTicks"] as? Int { XCTAssertEqual(ticks, expectedTicks, "\(name) ticks") }
            ran += 1
        }
        XCTAssertEqual(ran, 7)
    }

    func testDateHeaderCases() throws {
        for test in try cases("dateHeaders") {
            let g = given(test), e = expected(test), name = id(test)
            let title: String?
            switch g["level"] as? String {
            case "day": title = DateHeader.day(day(g["selectedDay"]))
            case "recordedDays": title = DateHeader.year(month(g["committedMonth"]))
            case "month": title = DateHeader.year(month(g["visibleMonth"]))
            case "editor": title = DateHeader.editor(day(g["draftDay"]))
            default: title = nil   // 연간: each year block carries its year
            }
            XCTAssertEqual(title, e["globalTitle"] as? String, name)
            // ExploreView/EditorView centre the title in a full-width ZStack with equal side padding,
            // so its centre is the viewport centre whatever the side buttons measure.
            if let centre = e["titleCenterX"] as? Double {
                XCTAssertEqual(number(g["width"]) / 2, CGFloat(centre), name)
                XCTAssertEqual(e["anchor"] as? String, "viewportCenter", name)
            }
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
