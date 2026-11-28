import CoreGraphics
import Foundation

/// UX v0.4 wide-screen and folding-screen rules, ported from the shared reference
/// (../tokipin/native-spec/v0.4/adaptive-layout.cjs) and checked against the same JSON cases.
/// Lengths are points of the app window (never reduced by the keyboard).
enum Adaptive {
    static let twoPaneMinWidth: CGFloat = 600
    static let twoPaneMinHeight: CGFloat = 480
    static let regionMin: CGFloat = 300
    static let paneMaxWidth: CGFloat = 640
    static let yearFourColumnsFrom: CGFloat = 560

    struct Fold: Equatable {
        enum Orientation { case vertical, horizontal }
        var orientation: Orientation
        /// x of the left/right edges (vertical) or y of the top/bottom edges (horizontal), window coordinates.
        var start: CGFloat
        var end: CGFloat
        var separating: Bool
    }

    enum Layout: Equatable {
        /// One column, centred in the window or in the larger side of a separating fold.
        case single(content: CGRect)
        /// Calendar on the left, day on the right, both against the split.
        case sideBySide(calendar: CGRect, day: CGRect)
        /// Day above a separating horizontal fold, calendar below it.
        case stacked(day: CGRect, calendar: CGRect)

        var isTwoPane: Bool { if case .single = self { false } else { true } }
    }

    private enum Align { case start, center, end }

    private static func fit(_ region: CGRect, _ align: Align) -> CGRect {
        let width = min(paneMaxWidth, region.width)
        let free = region.width - width
        let x = region.minX + (align == .start ? 0 : align == .end ? free : free / 2)
        return CGRect(x: x, y: region.minY, width: width, height: region.height)
    }

    static func layout(width: CGFloat, height: CGFloat, fold: Fold? = nil, journalEmpty: Bool = false, sampleTour: Bool = false) -> Layout {
        let twoPanes = !journalEmpty && !sampleTour
        func single(_ region: CGRect) -> Layout { .single(content: fit(region, .center)) }
        if let fold, fold.separating {
            if fold.orientation == .vertical {
                let left = CGRect(x: 0, y: 0, width: fold.start, height: height)
                let right = CGRect(x: fold.end, y: 0, width: width - fold.end, height: height)
                if twoPanes, left.width >= regionMin, right.width >= regionMin {
                    return .sideBySide(calendar: fit(left, .end), day: fit(right, .start))
                }
                return single(right.width > left.width ? right : left)
            }
            let top = CGRect(x: 0, y: 0, width: width, height: fold.start)
            let bottom = CGRect(x: 0, y: fold.end, width: width, height: height - fold.end)
            if twoPanes, top.height >= regionMin, bottom.height >= regionMin {
                return .stacked(day: fit(top, .center), calendar: fit(bottom, .center))
            }
            return single(bottom.height > top.height ? bottom : top)
        }
        if twoPanes, width >= twoPaneMinWidth, height >= twoPaneMinHeight {
            let half = width / 2
            return .sideBySide(calendar: fit(CGRect(x: 0, y: 0, width: half, height: height), .end),
                               day: fit(CGRect(x: half, y: 0, width: half, height: height), .start))
        }
        return single(CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// The level the calendar pane shows: the level itself, or the one a day was opened from.
    static func calendarLevel(_ level: ExploreLevel, dayReturnLevel: ExploreLevel) -> ExploreLevel {
        level == .day ? dayReturnLevel : level
    }

    enum SingleScreen: Equatable {
        case editor(DayKey)
        case search
        case day(DayKey, returnToSearchResults: Bool)
        case calendar(ExploreLevel)
    }

    struct PaneScreens: Equatable {
        /// nil while the calendar pane shows the search list.
        var calendar: ExploreLevel?
        var calendarInert: Bool
        var dayIsEditor: Bool
        var dayDate: DayKey
    }

    static func singleScreen(level: ExploreLevel, selectedDay: DayKey, searching: Bool, searchHighlight: Bool, editorDay: DayKey?) -> SingleScreen {
        if let editorDay { return .editor(editorDay) }
        if searching { return .search }
        if level == .day { return .day(selectedDay, returnToSearchResults: searchHighlight) }
        return .calendar(level)
    }

    static func paneScreens(level: ExploreLevel, dayReturnLevel: ExploreLevel, selectedDay: DayKey, searching: Bool, searchHighlight: Bool, editorDay: DayKey?) -> PaneScreens {
        PaneScreens(calendar: searching || searchHighlight ? nil : calendarLevel(level, dayReturnLevel: dayReturnLevel),
                    calendarInert: editorDay != nil, dayIsEditor: editorDay != nil, dayDate: editorDay ?? selectedDay)
    }

    struct PaneState: Equatable {
        var level: ExploreLevel
        var dayReturnLevel: ExploreLevel
        var selectedDay: DayKey
        var recordedMonth: MonthKey?
    }

    enum PaneAction {
        case tapDate(DayKey)
        case weekRailTap(DayKey)
        case daySwipe(Int)
        case viewMenu(ExploreLevel)
        case tapMonth(selectedDayAfter: DayKey)
        case recordedMonthCommit(MonthKey)
        case today(DayKey)
        case pinch(inCalendarPane: Bool, scaleAtRelease: CGFloat, anchorDay: DayKey?)
    }

    /// One action in the two-pane layouts. `level == .day` only records that the day pane was used
    /// last. One tick when the selected date, the calendar pane's level or the committed 기록한 날
    /// month really changes; 오늘 is silent.
    static func navigate(_ state: PaneState, _ action: PaneAction, hapticsEnabled: Bool = true) -> (state: PaneState, calendarLevel: ExploreLevel, ticks: Int) {
        var s = state
        let before = calendarLevel(state.level, dayReturnLevel: state.dayReturnLevel)
        var silent = false
        func useDayPane() { if s.level != .day { s.dayReturnLevel = s.level; s.level = .day } }
        switch action {
        case .tapDate(let day), .weekRailTap(let day): s.selectedDay = day; useDayPane()
        case .daySwipe(let days): s.selectedDay = s.selectedDay.adding(days: days); useDayPane()
        case .viewMenu(let level): s.level = level
        case .tapMonth(let day): s.selectedDay = day; s.level = .month
        case .recordedMonthCommit(let month): s.recordedMonth = month; s.level = .records
        case .today(let day): s.selectedDay = day; silent = true
        case .pinch(let inCalendar, let scale, let anchor):
            guard inCalendar else { break }
            let step = scale >= 1.25 ? 1 : scale <= 0.8 ? -1 : 0
            guard step != 0, let next = ExploreLevel(rawValue: before.rawValue + step) else { break }
            if let anchor { s.selectedDay = anchor }
            if next == .day { useDayPane() } else { s.level = next }
        }
        let shown = calendarLevel(s.level, dayReturnLevel: s.dayReturnLevel)
        let changed = s.selectedDay != state.selectedDay || shown != before || s.recordedMonth != state.recordedMonth
        return (s, shown, hapticsEnabled && changed && !silent ? 1 : 0)
    }

    /// The calendar pane's view menu: no 일간 entry.
    static let calendarMenu: [ExploreLevel] = [.records, .month, .year]

    struct CalendarChrome: Equatable { var back: ExploreLevel?; var title: String?; var titleCenterX: CGFloat? }
    struct DayChrome: Equatable { var title: String; var titleCenterX: CGFloat; var more: Bool; var editsExisting: Bool; var opens: DayKey; var keyboard: Bool }

    static func calendarChrome(pane: CGRect, level: ExploreLevel, dayReturnLevel: ExploreLevel, visibleMonth: MonthKey, recordedMonth: MonthKey) -> CalendarChrome {
        let shown = calendarLevel(level, dayReturnLevel: dayReturnLevel)
        let year: String? = switch shown {
        case .month: String(visibleMonth.year)
        case .records: String(recordedMonth.year)
        default: nil
        }
        return CalendarChrome(back: shown == .year ? nil : .year, title: year, titleCenterX: year == nil ? nil : pane.midX)
    }

    static func dayChrome(pane: CGRect, selectedDay: DayKey, dayHasRecords: Bool) -> DayChrome {
        DayChrome(title: String(format: "%04d.%02d", selectedDay.year, selectedDay.month), titleCenterX: pane.midX,
                  more: dayHasRecords, editsExisting: dayHasRecords, opens: selectedDay, keyboard: !dayHasRecords)
    }

    static func yearColumns(paneWidth: CGFloat) -> Int { paneWidth >= yearFourColumnsFrom ? 4 : 3 }
}
