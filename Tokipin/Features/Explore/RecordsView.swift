import SwiftUI

/// 기록한 날 (v0.2): one month per page. Swipe the body left/right for ±1 month, read the
/// month's cards vertically, and use the month rail on top to jump or fling across months.
struct RecordsView: View {
    @Environment(AppModel.self) private var app
    @Environment(RecordStore.self) private var store
    let onLongPress: (DayKey) -> Void
    /// Body drag progress (−1…1) mirrored by the rail while the finger is down.
    @State private var progress: CGFloat = 0

    /// Months with saved items plus this month (v0.3); every move steps through this list.
    private var months: [MonthKey] {
        RecordedMonths.visible(recordedMonths: store.recordedMonths, today: app.today)
    }

    var body: some View {
        let months = months
        VStack(spacing: 0) {
            MonthRail(committed: app.recordsMonth, progress: progress, months: months) { month in
                app.commitRecordsMonth(month)
            }
            .frame(height: 66)
            SwipePager(region: .recordsBody, onProgress: { progress = $0 },
                       canMove: { RecordedMonths.neighbour(of: app.recordsMonth, step: $0, in: months) != nil },
                       onCommit: { delta in
                if let next = RecordedMonths.neighbour(of: app.recordsMonth, step: delta, in: months) {
                    app.commitRecordsMonth(next)
                }
            }) { page in
                if let month = RecordedMonths.neighbour(of: app.recordsMonth, step: page, in: months) {
                    RecordsMonthPage(month: month, onLongPress: onLongPress)
                } else {
                    Color.clear   // past either end: empty margin, nothing to focus
                }
            }
        }
        .onAppear { reconcile(months) }
        .onChange(of: months) { _, list in reconcile(list) }
        .onChange(of: app.level) { _, level in if level == .records { reconcile(months) } }
        .onChange(of: app.recordsMonth) { _, month in
            // Only a settled month is announced; previews and cancelled drags never are.
            if app.level == .records, store.days(in: month).isEmpty, UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: EmptyStateText.month(month))
            }
        }
    }

    /// The committed month stays while it is shown; otherwise the nearest shown month (the more
    /// recent on a tie). Silent: no haptic and the selected day is untouched.
    private func reconcile(_ list: [MonthKey]) {
        let resolved = RecordedMonths.resolve(app.recordsMonth, in: list)
        if resolved != app.recordsMonth { app.commitRecordsMonth(resolved, haptic: false) }
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
                if days.isEmpty {
                    // Part of this month's page, so it travels with the body swipe and comes back on cancel.
                    EmptyRecordArt(label: EmptyStateText.month(month))
                        .containerRelativeFrame([.horizontal, .vertical])
                } else {
                BentoGrid {
                    ForEach(days, id: \.self) { day in
                        RecordCard(day: day, onLongPress: onLongPress)
                        EmptyBento()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 24)
                }
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

/// One recorded day: its date, then every item in entry order on one line, joined by " · ".
/// Place and time carry small icons; emoji read inline. As wide as its content.
struct RecordCard: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let day: DayKey
    let onLongPress: (DayKey) -> Void

    var body: some View {
        let items = store.items(on: day)
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: String(localized: "\(day.day) / \(day.weekdaySymbol)"))
                .font(.brand(12))
                .foregroundStyle(Palette.secondary)
                .frame(height: 17, alignment: .leading)
            ItemFlow {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ItemChunk(item: item, last: index == items.count - 1)
                }
            }
            // A card widened to fill its row keeps its content 18 from the trailing edge.
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.leading, 13)
        .padding(.trailing, 18)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: 14, fill: Palette.surface.opacity(0.88))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .pinchTarget(.day(day), in: .records)
        .id(day)
        .onTapGesture { app.openDay(day) }
        .onLongPressGesture(minimumDuration: 0.45) { onLongPress(day) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.spokenLabel), \(items.map(\.displayValue).joined(separator: ", "))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "이날 기록 삭제") { onLongPress(day) }
    }
}

/// One item with its trailing separator, kept together when the line wraps.
private struct ItemChunk: View {
    let item: RecordItem
    let last: Bool

    var body: some View {
        HStack(spacing: 0) {
            if item.kind == .place || item.kind == .time {
                Image(item.kind == .place ? "KindPlace" : "KindTime")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Palette.secondary)
                    .padding(.trailing, 2)
            }
            Text(verbatim: item.displayValue)
                .font(.brand(15))
                .foregroundStyle(Palette.primary)
                .lineLimit(nil)
            if !last {
                // Separator box: 9 wide, 4 on each side of the dot.
                Text(verbatim: "·")
                    .font(.brand(15))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 9)
            }
        }
        .frame(minHeight: 24)
    }
}

/// Lays chunks left to right with a space between and wraps at chunk boundaries; a chunk wider
/// than the line wraps inside itself. Reports the widest line, so a wrapped card hugs its text.
private struct ItemFlow: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in arrange(width: bounds.width, subviews: subviews).frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth { size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)) }
            if x > 0 && x + spacing + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            let originX = x == 0 ? 0 : x + spacing
            frames.append(CGRect(origin: CGPoint(x: originX, y: y), size: size))
            x = originX + size.width
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x)
        }
        return (frames, CGSize(width: widest, height: y + lineHeight))
    }
}

/// Decoration filling left-over width in a row; never focusable or tappable.
private struct EmptyBento: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.10))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Places (card, bento) pairs by `BentoRows`: content-sized cards, pairs when both fit on one
/// line, empty bentos alternating right → left. Unused bentos get zero size.
private struct BentoGrid: Layout {
    struct Cache {
        var width: CGFloat = -1
        var rows: [BentoRows.Row] = []
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    private func rows(width: CGFloat, subviews: Subviews, cache: inout Cache) -> [BentoRows.Row] {
        if cache.width == width { return cache.rows }
        var cards: [BentoRows.Card] = []
        for index in stride(from: 0, to: subviews.count, by: 2) {
            let card = subviews[index]
            // Rounded up so placing a card at its measured width never wraps its last item.
            let natural = card.sizeThatFits(.unspecified)
            if natural.width.rounded(.up) <= width {
                cards.append(.init(width: natural.width.rounded(.up), height: natural.height.rounded(.up), wraps: false))
            } else {
                let wrapped = card.sizeThatFits(ProposedViewSize(width: width, height: nil))
                cards.append(.init(width: min(wrapped.width.rounded(.up), width), height: wrapped.height.rounded(.up), wraps: true))
            }
        }
        cache.width = width
        cache.rows = BentoRows.rows(cards, available: width)
        return cache.rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 390
        let rows = rows(width: width, subviews: subviews, cache: &cache)
        let height = rows.reduce(0) { $0 + $1.height } + BentoRows.gap * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let rows = rows(width: bounds.width, subviews: subviews, cache: &cache)
        var used = Set<Int>()
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            func placeBento(_ width: CGFloat) {
                let bento = subviews[row.cards[0] * 2 + 1]
                bento.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: row.height))
                used.insert(row.cards[0] * 2 + 1)
                x += width + BentoRows.gap
            }
            if let bento = row.bento, bento.side == .leading { placeBento(bento.width) }
            for (card, width) in zip(row.cards, row.widths) {
                subviews[card * 2].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: row.height))
                x += width + BentoRows.gap
            }
            if let bento = row.bento, bento.side == .trailing { placeBento(bento.width) }
            y += row.height + BentoRows.gap
        }
        for index in stride(from: 1, to: subviews.count, by: 2) where !used.contains(index) {
            subviews[index].place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: .zero)
        }
    }
}

/// The shown months as a row of numbers with the committed month fixed at the centre. Native
/// horizontal scrolling with view-aligned snapping handles flings across many months; the body's
/// drag moves it by the same fraction so both travel together. A small year sits over the slot
/// nearest the centre for each other year; its space is always reserved so nothing shifts.
struct MonthRail: View {
    let committed: MonthKey
    /// Body drag progress, in slots (−1…1).
    let progress: CGFloat
    /// Shown months, oldest first.
    let months: [MonthKey]
    let onSelect: (MonthKey) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var slot: CGFloat = 60
    @State private var position = ScrollPosition(idType: MonthKey.self)
    @State private var centerOffset: CGFloat = 0
    @State private var userScrolling = false

    private func month(at index: Int) -> MonthKey {
        months[min(max(index, 0), months.count - 1)]
    }

    /// Year hints over the whole list (same on screen as the visible-window rule).
    private var hints: [MonthKey: String] { RecordedMonths.hints(committed: committed, in: months) }

    var body: some View {
        let hints = hints
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        label(month, hint: hints[month]).id(month)
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
                let landed = month(at: Int((centerOffset / slot).rounded()))
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
            .onChange(of: months) { _, _ in position.scrollTo(id: committed, anchor: .center) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("월 선택")
        .accessibilityAdjustableAction { direction in
            // Same neighbours as the body swipe.
            let step = direction == .increment ? 1 : direction == .decrement ? -1 : 0
            if step != 0, let next = RecordedMonths.neighbour(of: committed, step: step, in: months) { onSelect(next) }
        }
    }

    /// Month shown in the centre right now: the rail's own position while it is flung,
    /// otherwise the body-drag preview.
    private var centred: MonthKey {
        if userScrolling { return month(at: Int((centerOffset / slot).rounded())) }
        guard abs(progress) >= 0.5 else { return committed }
        return RecordedMonths.neighbour(of: committed, step: progress > 0 ? 1 : -1, in: months) ?? committed
    }

    private func label(_ month: MonthKey, hint: String?) -> some View {
        let isCentre = month == centred
        return Button {
            onSelect(month)
        } label: {
            VStack(spacing: 0) {
                // Reserved line: the hint never moves the number's baseline or the capsule.
                Text(verbatim: hint ?? " ")
                    .font(.brand(10))
                    .foregroundStyle(Palette.secondary)
                    .opacity(hint == nil ? 0 : 1)
                    .animation(reduceMotion ? nil : .easeOut(duration: InteractionRules.commitDuration), value: hint)
                    .frame(height: 14)
                Text("\(month.month)")
                    .font(.brand(isCentre ? 20 : 16, isCentre ? .semibold : .regular))
                    .foregroundStyle(isCentre ? Palette.onFocus : Palette.secondary)
                    .frame(width: 40, height: 40)
                    .background(isCentre ? Palette.focus : .clear, in: Circle())
            }
            .frame(width: slot, height: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // One element per slot: the full year and month, selected state; the hint is merged in.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(month.spokenLabel))
        .accessibilityAddTraits(month == committed ? [.isButton, .isSelected] : .isButton)
    }
}
