import SwiftUI

/// 일간: a 7-day strip and the selected day's items in the order they were written.
struct DayView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let onUndo: (PendingUndo) -> Void
    let onError: (Error) -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            WeekStrip()
            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)
            ScrollView {
                dayBody
                    .id(app.selectedDay)
                    .transition(.asymmetric(
                        insertion: .move(edge: app.dayTransitionEdge).combined(with: .opacity),
                        removal: .move(edge: app.dayTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .gesture(daySwipe)
        }
    }

    @ViewBuilder
    private var dayBody: some View {
        let items = store.items(on: app.selectedDay)
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
                        leadCard(item)
                            .padding(.bottom, 14)
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
                Text(item.value)
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
        .overlay(highlight(item, cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: RecordItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if item.kind == .place || item.kind == .time { KindIcon(kind: item.kind, size: 17) }
                Text(item.value)
                    .font(.brand(item.kind == .emoji ? 26 : 21, item.kind == .word ? .regular : .regular))
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

    @ViewBuilder
    private func highlight(_ item: RecordItem, cornerRadius: CGFloat) -> some View {
        if app.searchHighlight == item.id {
            RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Palette.secondary.opacity(0.8), lineWidth: 1.5)
        }
    }

    private func itemMenu(_ item: RecordItem) -> some View {
        Menu {
            Button { app.openEditor(for: app.selectedDay, item: item.id) } label: { Label("수정", systemImage: "pencil") }
            Button(role: .destructive) { delete(item) } label: { Label("삭제", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15))
                .foregroundStyle(Palette.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(item.value) 더보기")
    }

    private func delete(_ item: RecordItem) {
        let day = app.selectedDay
        do {
            guard let removed = try store.deleteItem(item.id, on: day) else { return }
            onUndo(PendingUndo(message: String(localized: "항목을 삭제했어요.")) {
                do { try store.restoreItem(removed.item, at: removed.index, on: day) } catch { onError(error) }
            })
        } catch {
            onError(error)
        }
    }

    /// Swipe the body left for the next day, right for the previous day.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width * 0.35
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                if horizontal && value.translation.width < -60 {
                    app.select(app.selectedDay.adding(days: 1))
                } else if horizontal && value.translation.width > 60 {
                    app.select(app.selectedDay.adding(days: -1))
                }
                withAnimation(.easeOut(duration: 0.18)) { dragOffset = 0 }
            }
    }
}

/// 일~토 strip; dragging moves a week and keeps the weekday.
struct WeekStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let start = app.selectedDay.weekStart
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = start.adding(days: offset)
                let selected = day == app.selectedDay
                Button { app.select(day) } label: {
                    VStack(spacing: 8) {
                        Text(DayKey.weekdaySymbols[offset])
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
        .id(start)
        .transition(.asymmetric(
            insertion: .move(edge: app.dayTransitionEdge).combined(with: .opacity),
            removal: .move(edge: app.dayTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
        ))
        .frame(maxWidth: .infinity)
        .clipped()
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -40 { app.select(app.selectedDay.adding(days: 7)) }
                if value.translation.width > 40 { app.select(app.selectedDay.adding(days: -7)) }
            }
        )
    }
}
