import SwiftUI

/// 일간: a 7-day rail and the selected day's items in the order they were written.
/// Both page with the finger 1:1 (UX v0.1 §2): the body by one day, the rail by one week.
struct DayView: View {
    @Environment(AppModel.self) private var app
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SwipePager(region: .weekRail, onCommit: move) { page in
                WeekRail(center: app.selectedDay.adding(days: page * 7))
            }
            .frame(height: 74)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)
            SwipePager(region: .dayBody, onCommit: move) { page in
                ScrollView {
                    DayBody(day: app.selectedDay.adding(days: page), onUndo: onUndo, onError: onError)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .accessibilityAction(named: "다음 날") { move(1) }
        .accessibilityAction(named: "이전 날") { move(-1) }
    }

    private func move(_ days: Int) {
        app.select(app.selectedDay.adding(days: days))
    }
}

/// Three pages (previous, current, next) that follow a horizontal drag 1:1 and settle
/// or snap back on release. Vertical drags are left to the scroll view inside.
struct SwipePager<Page: View>: View {
    let region: InteractionRules.SwipeRegion
    let onCommit: (Int) -> Void
    @ViewBuilder let page: (Int) -> Page

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var axis: InteractionRules.Axis = .undecided
    @State private var fromEdge = false
    @State private var settling = false

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
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard !settling else { return }
                if axis == .undecided {
                    axis = InteractionRules.axis(dx: value.translation.width, dy: value.translation.height)
                    // Screen coordinates: a drag starting at the leading edge belongs to the system.
                    fromEdge = value.startLocation.x < InteractionRules.edgeReserve
                }
                if axis == .horizontal && !fromEdge {
                    offset = value.translation.width
                }
            }
            .onEnded { value in
                defer { axis = .undecided }
                guard !settling, axis == .horizontal else { return }
                let delta = InteractionRules.swipeDelta(
                    width: width, dx: value.translation.width, dy: value.translation.height,
                    vx: value.velocity.width, region: region, systemEdgeBack: fromEdge)
                settle(delta: delta, width: width)
            }
    }

    private func settle(delta: Int, width: CGFloat) {
        guard delta != 0 else {
            withAnimation(.easeOut(duration: InteractionRules.cancelDuration)) { offset = 0 }
            return
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: InteractionRules.reduceMotionDuration)) {
                offset = 0
                onCommit(delta)
            }
            return
        }
        settling = true
        withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
            offset = delta > 0 ? -width : width
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onCommit(delta)
                offset = 0
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

/// One day's items: the first in a large card, the rest as rows.
struct DayBody: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let day: DayKey
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    var body: some View {
        let items = store.items(on: day)
        if items.isEmpty {
            Text("이날 남긴 기록이 없어요.")
                .font(.brand(15))
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
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
            itemMenu(item)
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
                itemMenu(item)
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

    private func itemMenu(_ item: RecordItem) -> some View {
        Menu {
            Button { app.openEditor(for: day, item: item.id) } label: { Label("수정", systemImage: "pencil") }
            Button(role: .destructive) { delete(item) } label: { Label("삭제", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15))
                .foregroundStyle(Palette.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(item.displayValue) 더보기")
    }

    private func delete(_ item: RecordItem) {
        do {
            guard let removed = try store.deleteItem(item.id, on: day) else { return }
            onUndo(PendingUndo(message: String(localized: "항목을 삭제했어요.")) {
                do { try store.restoreItem(removed.item, at: removed.index, on: day) } catch { onError(error) }
            })
        } catch {
            onError(error)
        }
    }
}
