import SwiftUI

/// UX v0.4 window container. Reads the app window's size (the keyboard never shrinks it), decides
/// one column or two panes with `Adaptive.layout`, and draws the same state either way: one column
/// is the v0.3 screen; two panes put the calendar (or the search list) on the left and the day on
/// the right. The editor is a layer here, not a full-screen cover, so a window change only moves
/// its frame: the same field keeps its text, caret and keyboard. Folds are read from iOS 27.1 on;
/// below that a window has none.
struct PaneContainer: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let editorAllowsKeyboard: Bool
    @State private var window: CGSize = .zero
    /// The window's own safe area (status bar, home indicator, rounded corners).
    @State private var insets = EdgeInsets()

    var body: some View {
        let layout = Adaptive.layout(width: window.width, height: window.height, fold: nil, journalEmpty: store.isEmpty)
        let panes = window != .zero && layout.isTwoPane
        ZStack(alignment: .topLeading) {
            BrandBackground()
            switch layout {
            case .sideBySide(let calendar, let day) where panes:
                calendarPane(calendar)
                dayPane(day)
                Rectangle().fill(Palette.line)
                    .frame(width: 1, height: window.height)
                    .offset(x: (calendar.maxX + day.minX) / 2)
                    .accessibilityHidden(true)
            case .stacked(let day, let calendar) where panes:
                // Reading order follows the screen: the day above, then the calendar.
                dayPane(day)
                calendarPane(calendar)
                Rectangle().fill(Palette.line)
                    .frame(width: day.width, height: 1)
                    .offset(x: day.minX, y: (day.maxY + calendar.minY) / 2)
                    .accessibilityHidden(true)
            default:
                ExploreView()
                    .safeAreaPadding(insets)
                    .frame(width: window.width, height: window.height)
                    .accessibilityHidden(app.editorDay != nil)
            }
            // Same place in the tree in every layout, so the editor is never rebuilt.
            if let day = app.editorDay {
                let frame = editorFrame(layout, panes: panes)
                EditorView(day: day, focusItem: app.editorFocusItem, startsWithKeyboard: app.editorStartsWithKeyboard,
                           allowsKeyboard: editorAllowsKeyboard)
                    .id(day)
                    .safeAreaPadding(paneInsets(frame))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        // Panes are placed in window coordinates; each gets the part of the window's safe area that
        // falls in its frame. The keyboard still insets the editor.
        .ignoresSafeArea(.container)
        .background { Color.clear.ignoresSafeArea().onGeometryChange(for: CGSize.self) { $0.size } action: { window = $0 } }
        .background { Color.clear.onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 } }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: app.editorDay)
        .onChange(of: panes, initial: true) { _, two in app.twoPane = two }
    }

    private func editorFrame(_ layout: Adaptive.Layout, panes: Bool) -> CGRect {
        guard panes else { return CGRect(origin: .zero, size: window) }
        switch layout {
        case .sideBySide(_, let day), .stacked(let day, _): return day
        case .single: return CGRect(origin: .zero, size: window)
        }
    }

    /// The window's safe area that overlaps a pane: a lower pane starts at its header.
    private func paneInsets(_ frame: CGRect) -> EdgeInsets {
        EdgeInsets(top: max(insets.top - frame.minY, 0),
                   leading: max(insets.leading - frame.minX, 0),
                   bottom: max(frame.maxY - (window.height - insets.bottom), 0),
                   trailing: max(frame.maxX - (window.width - insets.trailing), 0))
    }

    private func calendarPane(_ frame: CGRect) -> some View {
        let editing = app.editorDay != nil
        return ExploreView(role: .calendar)
            .safeAreaPadding(paneInsets(frame))
            .frame(width: frame.width, height: frame.height)
            // While editing, the calendar is dimmed and out of reach of touch and VoiceOver.
            .overlay { if editing { Color.black.opacity(0.45).allowsHitTesting(true).accessibilityHidden(true) } }
            .allowsHitTesting(!editing)
            .accessibilityHidden(editing)
            .offset(x: frame.minX, y: frame.minY)
    }

    private func dayPane(_ frame: CGRect) -> some View {
        ExploreView(role: .day)
            .safeAreaPadding(paneInsets(frame))
            .frame(width: frame.width, height: frame.height)
            .accessibilityHidden(app.editorDay != nil)
            .offset(x: frame.minX, y: frame.minY)
    }
}
