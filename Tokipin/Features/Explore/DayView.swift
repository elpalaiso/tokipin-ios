import SwiftUI

/// 일간: a 7-day rail and the selected day's items in the order they were written.
/// Both page with the finger 1:1 (UX v0.1 §2): the body by one day, the rail by one week.
struct DayView: View {
    @Environment(AppModel.self) private var app
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SwipePager(region: .weekRail, canMove: { canReach(app.selectedDay.adding(days: $0 * 7).weekStart()) },
                       onCommit: move) { page in
                WeekRail(center: app.selectedDay.adding(days: page * 7))
            }
            .frame(height: 74)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)
            SwipePager(region: .dayBody, canMove: { canReach(app.selectedDay.adding(days: $0)) }, onCommit: move) { page in
                DayPage(day: app.selectedDay.adding(days: page), onUndo: onUndo, onError: onError)
            }
        }
        .accessibilityAction(named: "다음 날") { if canReach(app.selectedDay.adding(days: 1)) { move(1) } }
        .accessibilityAction(named: "이전 날") { move(-1) }
    }

    /// Days run up to the last day of this month (the newest a record can go).
    private func canReach(_ day: DayKey) -> Bool {
        day <= CalendarRange.lastWritableDay(today: app.today)
    }

    private func move(_ days: Int) {
        app.select(min(app.selectedDay.adding(days: days), CalendarRange.lastWritableDay(today: app.today)))
    }
}

/// Three pages (previous, current, next) that follow a horizontal drag 1:1 and settle
/// or snap back on release. Vertical drags are left to the scroll view inside.
/// A pinch starting mid-drag cancels the move (v0.2: no month/day commit together with a pinch).
struct SwipePager<Page: View>: View {
    let region: InteractionRules.SwipeRegion
    /// Drag progress toward the next page (+1) or previous page (−1); mirrors the body for linked views.
    var onProgress: ((CGFloat) -> Void)? = nil
    /// False for a page outside the range: the drag resists and settles back.
    var canMove: (Int) -> Bool = { _ in true }
    let onCommit: (Int) -> Void
    @ViewBuilder let page: (Int) -> Page

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var axis: InteractionRules.Axis = .undecided
    @State private var fromEdge = false
    @State private var settling = false
    @State private var cancelled = false
    @GestureState private var touching = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 0) {
                page(-1).frame(width: width).accessibilityHidden(true)
                page(0).frame(width: width)
                page(1).frame(width: width).accessibilityHidden(true)
            }
            .offset(x: -width + offset)
            .contentShape(Rectangle())
            .simultaneousGesture(drag(width: width))
        }
        .clipped()
        .onChange(of: app.isPinching) { _, pinching in
            if pinching { cancelDrag() }
        }
        .onChange(of: touching) { _, isTouching in
            // The system took the touch (e.g. pinch or call): settle back without committing.
            if !isTouching && !settling && offset != 0 { cancelDrag() }
        }
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard !settling, !cancelled else { return }
                if axis == .undecided {
                    axis = InteractionRules.axis(dx: value.translation.width, dy: value.translation.height)
                    // Screen coordinates: a drag starting at the leading edge belongs to the system.
                    fromEdge = value.startLocation.x < InteractionRules.edgeReserve
                }
                if axis == .horizontal && !fromEdge {
                    let towards = value.translation.width < 0 ? 1 : -1
                    // At the range's end the page only gives a little (rubber band).
                    offset = canMove(towards) ? value.translation.width : value.translation.width * 0.2
                    onProgress?(-offset / max(width, 1))
                }
            }
            .onEnded { value in
                defer { axis = .undecided; cancelled = false }
                guard !settling, !cancelled, axis == .horizontal else { return }
                let delta = InteractionRules.swipeDelta(
                    width: width, dx: value.translation.width, dy: value.translation.height,
                    vx: value.velocity.width, region: region, systemEdgeBack: fromEdge,
                    osCancel: app.isPinching)
                settle(delta: delta, width: width)
            }
    }

    private func cancelDrag() {
        guard !settling else { return }
        if touching { cancelled = true }
        axis = .undecided
        withAnimation(.easeOut(duration: InteractionRules.cancelDuration)) {
            offset = 0
            onProgress?(0)
        }
    }

    private func settle(delta: Int, width: CGFloat) {
        guard delta != 0, canMove(delta.signum()) else {
            withAnimation(.easeOut(duration: InteractionRules.cancelDuration)) {
                offset = 0
                onProgress?(0)
            }
            return
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: InteractionRules.reduceMotionDuration)) {
                offset = 0
                onProgress?(0)
                onCommit(delta)
            }
            return
        }
        settling = true
        withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
            offset = delta > 0 ? -width : width
            onProgress?(delta > 0 ? 1 : -1)
        }
        // A timer rather than the animation's completion: the completion can be dropped when
        // the linked view re-renders mid-animation, which would leave the pager stuck.
        DispatchQueue.main.asyncAfter(deadline: .now() + InteractionRules.commitDuration) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onCommit(delta)
                offset = 0
                onProgress?(0)
            }
            settling = false
        }
    }
}

/// 일~토 (or the device's week start) for the week containing `center`.
struct WeekRail: View {
    @Environment(AppModel.self) private var app
    let center: DayKey

    var body: some View {
        let start = center.weekStart()
        let symbols = DayKey.orderedWeekdaySymbols()
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = start.adding(days: offset)
                let selected = day == center
                Button { app.select(day) } label: {
                    VStack(spacing: 8) {
                        Text(symbols[offset])
                            .font(.brand(12))
                            .foregroundStyle(Palette.secondary)
                        Text("\(day.day)")
                            .font(.brand(17, selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Palette.onFocus : Palette.primary)
                            .frame(width: 34, height: 34)
                            .background(selected ? Palette.focus : .clear, in: Circle())
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
    }
}

/// One page of 일간: the shared empty art on an empty day, else the day's items.
struct DayPage: View {
    @Environment(RecordStore.self) private var store
    let day: DayKey
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    var body: some View {
        ScrollView {
            if store.items(on: day).isEmpty {
                EmptyRecordArt(label: EmptyStateText.day)
                    .containerRelativeFrame([.horizontal, .vertical])
            } else {
                DayBody(day: day, onUndo: onUndo, onError: onError)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// One day's items in saved order: the first in a large card, the rest as rows. Read-only;
/// editing goes through the bottom pencil.
struct DayBody: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let day: DayKey
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    var body: some View {
        let items = store.items(on: day)
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index == 0 {
                    leadCard(item).padding(.bottom, 14)
                } else {
                    row(item)
                }
            }
        }
    }

    private func leadCard(_ item: RecordItem) -> some View {
        HStack(alignment: .top) {
            HStack(spacing: 10) {
                if item.kind == .place || item.kind == .time { KindIcon(kind: item.kind, size: 22) }
                Text(item.displayValue)
                    .font(.brand(item.kind == .emoji ? 40 : 32, .medium, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.primary)
            }
            .padding(.top, 34)
            Spacer()
        }
        .padding(.leading, 22)
        .padding(.trailing, 6)
        .frame(minHeight: 128, alignment: .top)
        .glassCard(cornerRadius: 20, fill: Palette.surface.opacity(0.9))
        .overlay {
            if app.searchHighlight == item.id {
                RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.secondary.opacity(0.8), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: RecordItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if item.kind == .place || item.kind == .time { KindIcon(kind: item.kind, size: 17) }
                Text(item.displayValue)
                    .font(.brand(item.kind == .emoji ? 26 : 21))
                    .foregroundStyle(Palette.primary)
                Spacer()
            }
            .padding(.leading, 6)
            .frame(minHeight: 66)
            .background(app.searchHighlight == item.id ? Color.white.opacity(0.08) : .clear)
            .overlay(alignment: .leading) {
                if app.searchHighlight == item.id {
                    Rectangle().fill(Palette.secondary).frame(width: 2)
                }
            }
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
