import SwiftUI

/// 기록한 날 (v0.2): one month per page. Swipe the body left/right for ±1 month, read the
/// month's cards vertically, and use the month rail on top to jump or fling across months.
struct RecordsView: View {
    @Environment(AppModel.self) private var app
    let onLongPress: (DayKey) -> Void
    /// Body drag progress (−1…1) mirrored by the rail while the finger is down.
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            MonthRail(committed: app.recordsMonth, progress: progress) { month in
                app.commitRecordsMonth(month)
            }
            .frame(height: 52)
            SwipePager(region: .recordsBody, onProgress: { progress = $0 }, onCommit: { delta in
                app.commitRecordsMonth(app.recordsMonth.adding(months: delta))
            }) { page in
                RecordsMonthPage(month: app.recordsMonth.adding(months: page), onLongPress: onLongPress)
            }
        }
    }
}

/// One month's recorded days, newest first, as a vertical bento. The list's own
/// scroll never changes the month.
struct RecordsMonthPage: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let month: MonthKey
    let onLongPress: (DayKey) -> Void

    var body: some View {
        let days = store.days(in: month)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if days.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("이달에 남긴 기록이 없어요.")
                                .font(.brand(15))
                                .foregroundStyle(Palette.secondary)
                            OutlineCapsuleButton(title: "달력 보기") {
                                app.setLevel(.month)
                                app.requestReveal(app.selectedDay)
                            }
                        }
                        .padding(.top, 12)
                    } else {
                        ForEach(RecordsLayout.rows(days), id: \.first) { row in
                            if row.count == 1 {
                                RecordCard(day: row[0], large: true, onLongPress: onLongPress)
                            } else {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(row, id: \.self) { RecordCard(day: $0, large: false, onLongPress: onLongPress) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onAppear { scroll(proxy, days: days, to: app.selectedDay, anchorY: nil) }
            .onChange(of: app.reveal) { _, request in
                guard let request, app.level == .records, request.day.monthKey == month else { return }
                withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                    scroll(proxy, days: days, to: request.day, anchorY: request.anchorY)
                }
            }
        }
        .id(month) // a new month starts at its top; the same month keeps its place
    }

    /// The day's card, or the nearest recorded day of this month. The selected day is untouched.
    private func scroll(_ proxy: ScrollViewProxy, days: [DayKey], to day: DayKey, anchorY: CGFloat?) {
        guard day.monthKey == month, !days.isEmpty else { return }
        let anchor = UnitPoint(x: 0.5, y: anchorY ?? 0.4)
        if days.contains(day) {
            proxy.scrollTo(day, anchor: anchor)
        } else if let nearest = days.min(by: { abs($0.date.timeIntervalSince(day.date)) < abs($1.date.timeIntervalSince(day.date)) }) {
            proxy.scrollTo(nearest, anchor: anchor)
        }
    }
}

enum RecordsLayout {
    /// Bento rhythm: one wide card, then a pair, repeating.
    static func rows(_ days: [DayKey]) -> [[DayKey]] {
        var rows: [[DayKey]] = []
        var index = 0
        var wide = true
        while index < days.count {
            let size = wide ? 1 : min(2, days.count - index)
            rows.append(Array(days[index..<index + size]))
            index += size
            wide.toggle()
        }
        return rows
    }
}

struct RecordCard: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let day: DayKey
    let large: Bool
    let onLongPress: (DayKey) -> Void

    var body: some View {
        let items = store.items(on: day)
        let title = items.first { $0.kind != .emoji } ?? items.first
        let rest = items.filter { $0.id != title?.id }
        let emoji = rest.first { $0.kind == .emoji }
        let detail = rest.filter { $0.kind != .emoji }.map(\.displayValue)

        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%02d / %@", day.day, day.weekdaySymbol))
                .font(.brand(13))
                .foregroundStyle(Palette.secondary)
            Text(title?.displayValue ?? "")
                .font(.brand(large ? 28 : 21, .medium))
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .padding(.top, large ? 16 : 12)
            HStack(alignment: .bottom) {
                if large {
                    Text(detail.joined(separator: "  ·  "))
                        .font(.brand(14))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let emoji {
                        Text(emoji.value)
                            .font(.system(size: 22))
                            .frame(width: 48, height: 48)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                } else {
                    Text(emoji?.value ?? detail.first ?? "")
                        .font(.brand(13))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: large ? 148 : 128, alignment: .topLeading)
        .glassCard(cornerRadius: 18, fill: Palette.surface.opacity(0.88))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .pinchTarget(.day(day), in: .records)
        .id(day)
        .onTapGesture { app.openDay(day) }
        .onLongPressGesture(minimumDuration: 0.45) { onLongPress(day) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.label), \(items.map(\.displayValue).joined(separator: ", "))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "이날 기록 삭제") { onLongPress(day) }
    }
}

/// Month numbers flowing across years (… 11 12 1 2 …) with the committed month fixed at the
/// centre. Native horizontal scrolling with view-aligned snapping handles flings; the body's
/// drag moves it by the same fraction so both travel together.
struct MonthRail: View {
    let committed: MonthKey
    /// Body drag progress, in months (−1…1).
    let progress: CGFloat
    let onSelect: (MonthKey) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var slot: CGFloat = 60
    @State private var position = ScrollPosition(idType: MonthKey.self)
    @State private var centerOffset: CGFloat = 0
    @State private var userScrolling = false

    private static let first = MonthKey(year: 1970, month: 1)
    private static let count = 12 * 131 // 1970 … 2100
    private static func month(at index: Int) -> MonthKey { first.adding(months: index) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<Self.count, id: \.self) { index in
                        label(Self.month(at: index)).id(Self.month(at: index))
                    }
                }
                .scrollTargetLayout()
                .offset(x: userScrolling ? 0 : -progress * slot)
            }
            .contentMargins(.horizontal, max((geometry.size.width - slot) / 2, 0), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition($position, anchor: .center)
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x + $0.contentInsets.leading } action: { _, x in
                centerOffset = x
            }
            .onScrollPhaseChange { old, new in
                userScrolling = new == .tracking || new == .interacting || new == .decelerating
                // Commit only when a person's drag or fling comes to rest, never for our own scrolls.
                guard new == .idle else { return }
                let landed = Self.month(at: Int((centerOffset / slot).rounded()))
                if old == .decelerating || old == .tracking || old == .interacting {
                    if landed != committed { onSelect(landed) }
                } else if landed != committed {
                    // Our own scroll stopped short (lazy layout estimate): put the committed month back in the centre.
                    position.scrollTo(id: committed, anchor: .center)
                }
            }
            .onAppear { position.scrollTo(id: committed, anchor: .center) }
            .onChange(of: committed) { _, month in
                if reduceMotion || userScrolling {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { position.scrollTo(id: month, anchor: .center) }
                } else {
                    withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                        position.scrollTo(id: month, anchor: .center)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("월 선택")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSelect(committed.adding(months: 1))
            case .decrement: onSelect(committed.adding(months: -1))
            @unknown default: break
            }
        }
    }

    /// Month shown in the centre right now: the rail's own position while it is flung,
    /// otherwise the body-drag preview.
    private var centred: MonthKey {
        userScrolling ? Self.month(at: Int((centerOffset / slot).rounded()))
            : InteractionRules.previewMonth(committed: committed, dragFraction: progress)
    }

    private func label(_ month: MonthKey) -> some View {
        let isCentre = month == centred
        return Button {
            onSelect(month)
        } label: {
            Text("\(month.month)")
                .font(.brand(isCentre ? 20 : 16, isCentre ? .semibold : .regular))
                .foregroundStyle(isCentre ? Palette.onFocus : Palette.secondary)
                .frame(width: 40, height: 40)
                .background(isCentre ? Palette.focus : .clear, in: Circle())
                .frame(width: slot, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(String(month.year))년 \(month.month)월"))
        .accessibilityAddTraits(month == committed ? .isSelected : [])
    }
}
