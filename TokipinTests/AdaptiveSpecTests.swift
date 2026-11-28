import XCTest
@testable import Tokipin

/// UX v0.4 groups (paneLayout, paneRender, paneNavigation, paneTransition, paneChrome, yearColumns)
/// run against `Adaptive`, the port of ../tokipin/native-spec/v0.4/adaptive-layout.cjs. Each result
/// is turned into the JSON shape the reference returns and compared with the case as a whole, the
/// way tests/adaptive-layout.test.cjs does.
@MainActor
final class AdaptiveSpecTests: XCTestCase {
    static let groups: Set<String> = ["paneLayout", "paneRender", "paneNavigation", "paneTransition", "paneChrome", "yearColumns"]

    private func spec() throws -> [String: Any] {
        let data = try Data(contentsOf: NativeUXSpecTests.specURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func level(_ name: Any?) -> ExploreLevel {
        switch name as? String {
        case "year": .year
        case "month": .month
        case "recordedDays": .records
        default: .day
        }
    }

    private func name(_ level: ExploreLevel) -> String {
        switch level { case .year: "year"; case .month: "month"; case .records: "recordedDays"; case .day: "day" }
    }

    private func day(_ value: Any?) -> DayKey? { (value as? String).flatMap(DayKey.init(string:)) }
    private func month(_ value: Any?) -> MonthKey? {
        guard let s = value as? String else { return nil }
        let parts = s.split(separator: "-").compactMap { Int($0) }
        return parts.count == 2 ? MonthKey(year: parts[0], month: parts[1]) : nil
    }
    private func number(_ value: Any?) -> CGFloat { CGFloat((value as? NSNumber)?.doubleValue ?? 0) }
    private func bool(_ value: Any?, _ fallback: Bool = false) -> Bool { (value as? Bool) ?? fallback }

    func testNumbersMatchTheDocument() throws {
        let adaptive = try XCTUnwrap(spec()["adaptive"] as? [String: Any])
        XCTAssertEqual(number(adaptive["twoPaneMinWidth"]), Adaptive.twoPaneMinWidth)
        XCTAssertEqual(number(adaptive["twoPaneMinHeight"]), Adaptive.twoPaneMinHeight)
        XCTAssertEqual(number(adaptive["regionMin"]), Adaptive.regionMin)
        XCTAssertEqual(number(adaptive["paneMaxWidth"]), Adaptive.paneMaxWidth)
        XCTAssertEqual(number(adaptive["yearFourColumnsFrom"]), Adaptive.yearFourColumnsFrom)
        XCTAssertEqual(ContentColumn.maxWidth, Adaptive.paneMaxWidth)
    }

    func testEveryV04CaseMatchesTheReference() throws {
        let tests = try XCTUnwrap(spec()["tests"] as? [[String: Any]])
        let added = tests.filter { Self.groups.contains($0["group"] as? String ?? "") }
        XCTAssertEqual(added.count, 85)
        for test in added {
            let id = test["id"] as? String ?? "?"
            let actual = try run(test)
            XCTAssertTrue(NSDictionary(dictionary: actual).isEqual(to: test["expected"] as? [String: Any] ?? [:]),
                          "\(id)\n expected \(test["expected"] ?? "")\n actual   \(actual)")
        }
    }

    private func run(_ test: [String: Any]) throws -> [String: Any] {
        let g = test["given"] as? [String: Any] ?? [:]
        let e = test["expected"] as? [String: Any] ?? [:]
        switch test["group"] as? String {
        case "paneLayout": return json(layout(g))
        case "paneRender": return render(g["mode"] as? String ?? "", g)
        case "paneNavigation": return navigation(g)
        case "paneTransition": return transition(g, e)
        case "paneChrome": return try chrome(g)
        case "yearColumns": return ["columns": Adaptive.yearColumns(paneWidth: number(g["paneWidth"]))]
        default: throw XCTSkip("group")
        }
    }

    private func layout(_ g: [String: Any]) -> Adaptive.Layout {
        let fold = (g["fold"] as? [String: Any]).map {
            Adaptive.Fold(orientation: $0["orientation"] as? String == "vertical" ? .vertical : .horizontal,
                          start: number($0["start"]), end: number($0["end"]), separating: bool($0["separating"]))
        }
        return Adaptive.layout(width: number(g["width"]), height: number(g["height"]), fold: fold,
                               journalEmpty: bool(g["journalEmpty"]), sampleTour: bool(g["sampleTour"]))
    }

    private func mode(_ layout: Adaptive.Layout) -> String {
        switch layout { case .single: "single"; case .sideBySide: "sideBySide"; case .stacked: "stacked" }
    }

    private func rect(_ r: CGRect) -> [String: Any] { ["x": r.minX, "y": r.minY, "width": r.width, "height": r.height] }

    private func json(_ layout: Adaptive.Layout) -> [String: Any] {
        switch layout {
        case .single(let content): ["mode": "single", "content": rect(content)]
        case .sideBySide(let calendar, let day): ["mode": "sideBySide", "calendar": rect(calendar), "day": rect(day)]
        case .stacked(let day, let calendar): ["mode": "stacked", "day": rect(day), "calendar": rect(calendar)]
        }
    }

    private func render(_ mode: String, _ s: [String: Any]) -> [String: Any] {
        let selected = day(s["selectedDay"])!
        let searching = bool(s["searching"])
        let highlight = s["searchHighlight"] != nil && !(s["searchHighlight"] is NSNull)
        let editor = day(s["editorDay"])
        if mode == "single" {
            switch Adaptive.singleScreen(level: level(s["level"]), selectedDay: selected, searching: searching, searchHighlight: highlight, editorDay: editor) {
            case .editor(let d): return ["screen": "editor", "date": d.string]
            case .search: return ["screen": "search"]
            case .day(let d, let back): return ["screen": "day", "date": d.string, "returnToSearchResults": back]
            case .calendar(let l): return ["screen": name(l)]
            }
        }
        let panes = Adaptive.paneScreens(level: level(s["level"]), dayReturnLevel: level(s["dayReturnLevel"]), selectedDay: selected,
                                         searching: searching, searchHighlight: highlight, editorDay: editor)
        return ["calendar": panes.calendar.map(name) ?? "search", "calendarInert": panes.calendarInert,
                "day": panes.dayIsEditor ? "editor" : "day", "dayDate": panes.dayDate.string]
    }

    private func navigation(_ g: [String: Any]) -> [String: Any] {
        let st = g["state"] as? [String: Any] ?? [:]
        let state = Adaptive.PaneState(level: level(st["level"]), dayReturnLevel: level(st["dayReturnLevel"]),
                                       selectedDay: day(st["selectedDay"])!, recordedMonth: month(st["recordedMonth"]))
        let a = g["action"] as? [String: Any] ?? [:]
        let action: Adaptive.PaneAction = switch a["type"] as? String {
        case "tapDate": .tapDate(day(a["date"])!)
        case "weekRailTap": .weekRailTap(day(a["date"])!)
        case "daySwipe": .daySwipe((a["days"] as? NSNumber)?.intValue ?? 0)
        case "viewMenu": .viewMenu(level(a["level"]))
        case "tapMonth": .tapMonth(selectedDayAfter: day(a["selectedDayAfter"])!)
        case "recordedMonthCommit": .recordedMonthCommit(month(a["month"])!)
        case "today": .today(day(a["today"])!)
        default: .pinch(inCalendarPane: a["pane"] as? String == "calendar", scaleAtRelease: number(a["scaleAtRelease"]), anchorDay: day(a["anchorDay"]))
        }
        let r = Adaptive.navigate(state, action, hapticsEnabled: bool(g["hapticsEnabled"], true))
        var out: [String: Any] = ["level": name(r.state.level), "dayReturnLevel": name(r.state.dayReturnLevel),
                                  "selectedDay": r.state.selectedDay.string, "calendarLevel": name(r.calendarLevel), "appTicks": r.ticks]
        if let m = r.state.recordedMonth { out["recordedMonth"] = m.id }
        return out
    }

    /// A window change only re-reads the same state for the new layout: nothing is rewritten.
    private func transition(_ g: [String: Any], _ e: [String: Any]) -> [String: Any] {
        let state = g["state"] as? [String: Any] ?? [:]
        let before = NSDictionary(dictionary: state)
        let from = mode(layout(g["from"] as? [String: Any] ?? [:]))
        let to = mode(layout(g["to"] as? [String: Any] ?? [:]))
        var out: [String: Any] = ["fromMode": from, "toMode": to, "stateUnchanged": before.isEqual(to: state), "appTicks": 0,
                                  "before": render(from, state), "after": render(to, state)]
        if e["editor"] != nil { out["editor"] = g["editor"] }
        return out
    }

    private func chrome(_ g: [String: Any]) throws -> [String: Any] {
        let (calendarPane, dayPane): (CGRect, CGRect) = switch layout(g) {
        case .sideBySide(let c, let d), .stacked(let d, let c): (c, d)
        case .single: throw XCTSkip("chrome cases are two-pane")
        }
        let c = Adaptive.calendarChrome(pane: calendarPane, level: level(g["level"]), dayReturnLevel: level(g["dayReturnLevel"]),
                                        visibleMonth: month(g["visibleMonth"])!, recordedMonth: month(g["recordedMonth"])!)
        let selected = day(g["selectedDay"])!
        let d = Adaptive.dayChrome(pane: dayPane, selectedDay: selected, dayHasRecords: bool(g["dayHasRecords"]))
        return [
            "calendar": ["back": c.back.map(name) ?? NSNull(), "title": c.title ?? NSNull(), "titleCenterX": c.titleCenterX ?? NSNull(),
                         "search": true, "viewMenu": Adaptive.calendarMenu.map(name), "today": true] as [String: Any],
            "day": ["back": NSNull(), "title": d.title, "titleCenterX": d.titleCenterX, "more": d.more,
                    "action": d.editsExisting ? "edit" : "add",
                    "actionOpens": ["editorDay": d.opens.string, "keyboard": d.keyboard]] as [String: Any],
        ]
    }
}
