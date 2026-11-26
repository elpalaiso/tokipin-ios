import SwiftUI
import Observation

/// The four explore levels, from least to most detail. Pinch moves along this order.
enum ExploreLevel: Int, CaseIterable, Identifiable {
    case year, month, records, day

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day: "일간"
        case .records: "기록한 날"
        case .month: "월간 달력"
        case .year: "연간"
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

    func setLevel(_ newLevel: ExploreLevel) {
        guard newLevel != level else { return }
        level = newLevel
        Haptics.selection()
    }

    func select(_ day: DayKey, haptic: Bool = true) {
        guard day != selectedDay else { return }
        selectedDay = day
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
