import SwiftUI
import Observation

/// The four explore levels, from least to most detail. Pinch moves along this order.
/// Something a pinch can be anchored on: a date cell/card or a month in the year view.
enum PinchTarget: Hashable {
    case day(DayKey)
    case month(MonthKey)
}

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

/// Navigation state shared by explore, search and the editor.
@MainActor
@Observable
final class AppModel {
    var level: ExploreLevel = .records
    var selectedDay: DayKey = .today
    /// Month the month/records views are anchored on.
    var focusedMonth: MonthKey = DayKey.today.monthKey
    var editorDay: DayKey?
    var editorFocusItem: UUID?
    var isSearching = false
    var searchQuery = ""
    /// Set when a day is opened from search; the header then offers "검색 결과".
    var searchHighlight: UUID?
    /// Explore level and day to restore when search closes.
    var searchReturn: (ExploreLevel, DayKey)?
    var isShowingSettings = false
    /// Which side the next day slides in from (left/right swipe feedback).
    var dayTransitionEdge: Edge = .trailing
    /// On-screen frames (window coordinates) of dates and months, for pinch anchoring.
    @ObservationIgnored var pinchFrames: [PinchTarget: CGRect] = [:]

    func pinchTarget(at point: CGPoint) -> PinchTarget? {
        pinchFrames.first { $0.value.contains(point) }?.key
    }

    func setLevel(_ newLevel: ExploreLevel) {
        guard newLevel != level else { return }
        level = newLevel
        Haptics.selection()
    }

    func select(_ day: DayKey, haptic: Bool = true) {
        guard day != selectedDay else { return }
        dayTransitionEdge = day > selectedDay ? .trailing : .leading
        withAnimation(.easeOut(duration: 0.22)) {
            selectedDay = day
        }
        focusedMonth = day.monthKey
        if haptic { Haptics.selection() }
    }

    func openDay(_ day: DayKey) {
        select(day, haptic: false)
        setLevel(.day)
    }

    func goToday() {
        select(.today)
        focusedMonth = DayKey.today.monthKey
    }

    func openEditor(for day: DayKey, item: UUID? = nil) {
        editorFocusItem = item
        editorDay = day
    }
}

/// Registers a view's frame as a pinch anchor while it is on screen.
struct PinchTargetModifier: ViewModifier {
    @Environment(AppModel.self) private var app
    let target: PinchTarget

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { app.pinchFrames[target] = $0 }
            .onDisappear { app.pinchFrames[target] = nil }
    }
}

extension View {
    func pinchTarget(_ target: PinchTarget) -> some View {
        modifier(PinchTargetModifier(target: target))
    }
}
