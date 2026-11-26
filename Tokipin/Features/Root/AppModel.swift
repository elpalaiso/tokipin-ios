import SwiftUI
import Observation

/// Something a pinch can be anchored on: a date cell/card or a month in the year view.
enum PinchTarget: Hashable {
    case day(DayKey)
    case month(MonthKey)
}

/// The four explore levels, from least to most detail. Pinch moves along this order.
enum ExploreLevel: Int, CaseIterable, Identifiable {
    case year, month, records, day

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day: String(localized: "level.day", defaultValue: "일간")
        case .records: String(localized: "level.records", defaultValue: "기록한 날")
        case .month: String(localized: "level.month", defaultValue: "월간 달력")
        case .year: String(localized: "level.year", defaultValue: "연간")
        }
    }

    var systemImage: String {
        switch self {
        case .day: "doc.plaintext"
        case .records: "square.grid.2x2"
        case .month: "calendar"
        case .year: "circle.grid.2x2"
        }
    }

    var zoomedIn: ExploreLevel? { ExploreLevel(rawValue: rawValue + 1) }
    var zoomedOut: ExploreLevel? { ExploreLevel(rawValue: rawValue - 1) }
}

/// Ask the active explore view to bring a date into view.
struct RevealRequest: Equatable {
    let id = UUID()
    let day: DayKey
    /// Where the date should sit vertically (0 top … 1 bottom); nil = view's default.
    var anchorY: CGFloat?
}

/// Navigation state shared by explore, search and the editor.
/// Selected day, visible period and each view's scroll position are kept apart (UX v0.1 §2).
@MainActor
@Observable
final class AppModel {
    private(set) var level: ExploreLevel = .records
    private(set) var selectedDay: DayKey = .today
    /// Month/year currently in view. Scrolling changes only this, never the selection.
    var focusedMonth: MonthKey = DayKey.today.monthKey
    var editorDay: DayKey?
    var editorFocusItem: UUID?
    /// False when the editor is opened with the pencil: existing items show, keyboard stays down.
    var editorStartsWithKeyboard = true
    var isSearching = false
    var searchQuery = ""
    /// Set when a day is opened from search; the header then offers "검색 결과".
    var searchHighlight: UUID?
    /// Explore level and day to restore when search closes.
    var searchReturn: (ExploreLevel, DayKey)?
    var isShowingSettings = false
    /// View that opened 일간; closing the day returns there.
    private(set) var dayReturnLevel: ExploreLevel = .month
    private(set) var reveal: RevealRequest?
    /// 기록한 날: the one committed month (header year, body page, rail centre).
    private(set) var recordsMonth: MonthKey = DayKey.today.monthKey
    /// True while two fingers pinch; pagers cancel any unsettled horizontal move.
    var isPinching = false
    /// On-screen frames (window coordinates) of dates and months, per level, for pinch anchoring.
    @ObservationIgnored var pinchFrames: [ExploreLevel: [PinchTarget: CGRect]] = [:]

    /// Native haptic call; tests swap it to count ticks.
    @ObservationIgnored var hapticSink: () -> Void = { Haptics.tick() }
    @ObservationIgnored var hapticsEnabled: () -> Bool = { Haptics.isEnabled }

    /// The one path every navigation takes. Changes the date and/or level together and
    /// requests at most one selection tick, only if something really changed.
    @discardableResult
    func navigate(to day: DayKey? = nil, level newLevel: ExploreLevel? = nil, haptic: Bool = true,
                  keepRecordsMonth: Bool = false) -> Bool {
        let dayChanged = day.map { $0 != selectedDay } ?? false
        let levelChanged = newLevel.map { $0 != level } ?? false
        // Entering 기록한 날 opens the selected (or anchored) day's month; closing a day keeps it.
        if newLevel == .records, levelChanged, !keepRecordsMonth {
            recordsMonth = (day ?? selectedDay).monthKey
        }
        if let day, dayChanged {
            selectedDay = day
            focusedMonth = day.monthKey
        }
        if let newLevel, levelChanged {
            if newLevel == .day { dayReturnLevel = level }
            level = newLevel
        }
        let events: [InteractionRules.NavigationEvent] = (dayChanged ? [.selectedDateChanged] : []) + (levelChanged ? [.levelChanged] : [])
        if haptic, InteractionRules.ticks(for: events, enabled: hapticsEnabled()) == 1 { hapticSink() }
        return dayChanged || levelChanged
    }

    func setLevel(_ newLevel: ExploreLevel, haptic: Bool = true) {
        navigate(level: newLevel, haptic: haptic)
    }

    func select(_ day: DayKey, haptic: Bool = true) {
        navigate(to: day, haptic: haptic)
    }

    /// Tapping a date opens it in 일간 (one tick for date + level).
    func openDay(_ day: DayKey) {
        navigate(to: day, level: .day)
    }

    /// Closing 일간 returns to the view it was opened from, with that view's scroll intact.
    func closeDay() {
        navigate(level: dayReturnLevel == .day ? .month : dayReturnLevel, haptic: false, keepRecordsMonth: true)
    }

    /// The one place a 기록한 날 month is committed (body swipe, rail tap, rail settle).
    /// Selected day stays; at most one tick, none for the same month.
    @discardableResult
    func commitRecordsMonth(_ month: MonthKey, haptic: Bool = true) -> Bool {
        guard month != recordsMonth else { return false }
        recordsMonth = month
        if haptic, InteractionRules.ticks(for: [.recordedDaysMonthCommit], enabled: hapticsEnabled()) == 1 { hapticSink() }
        return true
    }

    /// 오늘: same view, today selected and scrolled into view even if already selected. No tick.
    func goToday(_ today: DayKey = .today) {
        navigate(to: today, haptic: false)
        focusedMonth = today.monthKey
        if level == .records { commitRecordsMonth(today.monthKey, haptic: false) }
        requestReveal(today)
    }

    func requestReveal(_ day: DayKey, anchorY: CGFloat? = nil) {
        reveal = RevealRequest(day: day, anchorY: anchorY)
    }

    /// Target under (or nearest to) a point in the given level; ties keep the selected day.
    func pinchTarget(at point: CGPoint, in level: ExploreLevel, visibleIn bounds: CGRect? = nil) -> (target: PinchTarget, frame: CGRect)? {
        var frames = pinchFrames[level] ?? [:]
        if let bounds { frames = frames.filter { $0.value.intersects(bounds) } }
        if let hit = frames.first(where: { $0.value.contains(point) }) { return (hit.key, hit.value) }
        func distance(_ rect: CGRect) -> CGFloat {
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return dx * dx + dy * dy
        }
        let nearest = frames.min { a, b in
            let da = distance(a.value), db = distance(b.value)
            if da != db { return da < db }
            return a.key == .day(selectedDay)
        }
        return nearest.map { ($0.key, $0.value) }
    }

    func openEditor(for day: DayKey, item: UUID? = nil, keyboard: Bool = true) {
        editorFocusItem = item
        editorStartsWithKeyboard = keyboard
        editorDay = day
    }
}

/// Registers a view's frame as a pinch anchor while it is on screen.
struct PinchTargetModifier: ViewModifier {
    @Environment(AppModel.self) private var app
    let target: PinchTarget
    let level: ExploreLevel

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                app.pinchFrames[level, default: [:]][target] = $0
            }
            .onDisappear { app.pinchFrames[level]?[target] = nil }
    }
}

extension View {
    func pinchTarget(_ target: PinchTarget, in level: ExploreLevel) -> some View {
        modifier(PinchTargetModifier(target: target, level: level))
    }
}
