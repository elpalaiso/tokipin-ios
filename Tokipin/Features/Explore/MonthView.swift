import SwiftUI

/// 월간 달력: every day of every month, scrolling vertically with native momentum.
/// The weekday row stays fixed; each month number sits outside its card above the 1st.
struct MonthView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var visibleMonth: MonthKey?
    @State private var didInitialScroll = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DayKey.orderedWeekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.brand(12))
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .accessibilityHidden(true)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(sections, id: \.id) { section in
                            switch section {
                            case .month(let month):
                                MonthGrid(month: month).id(month)
                            case .gap(let first, let last):
                                FoldRow(label: MonthKey.rangeLabel(first, last),
                                        spoken: String(localized: "\(first.spokenLabel)부터 \(last.spokenLabel)까지 기록 없는 \(CalendarRange.monthCount(first, last))개월"),
                                        expanded: app.expandedMonthGaps.contains(first)) {
                                    toggle(first)
                                }
                                .id(section.id)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $visibleMonth, anchor: .top)
                .onAppear {
                    guard !didInitialScroll else { return }
                    didInitialScroll = true
                    openGap(for: app.focusedMonth)
                    proxy.scrollTo(clamped(app.focusedMonth), anchor: .top)
                }
                .onChange(of: app.reveal) { _, request in
                    guard let request, app.level == .month else { return }
                    // Entering a folded month on purpose opens its period first.
                    let month = clamped(request.day.monthKey)
                    openGap(for: month)
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                            proxy.scrollTo(month, anchor: UnitPoint(x: 0.5, y: request.anchorY ?? 0))
                        }
                    }
                }
            }
        }
        .onChange(of: visibleMonth) { _, month in
            // Scrolling only changes the visible period; the selected day stays (UX v0.1 §2).
            if let month, app.level == .month { app.focusedMonth = month }
        }
    }

    private var recordedMonths: Set<MonthKey> { Set(store.records.keys.map(\.monthKey)) }

    /// From the first explorable month to this month; long empty periods folded.
    private var sections: [CalendarRange.MonthSection] {
        CalendarRange.monthSections(today: app.today, recordedMonths: recordedMonths, expanded: app.expandedMonthGaps)
    }

    private func clamped(_ month: MonthKey) -> MonthKey {
        let first = CalendarRange.firstMonth(today: app.today, earliestRecord: store.records.keys.min())
        return min(max(month, first), CalendarRange.lastMonth(today: app.today))
    }

    private func openGap(for month: MonthKey) {
        if let gap = CalendarRange.gap(containing: month, today: app.today, recordedMonths: recordedMonths) {
            app.expandedMonthGaps.insert(gap)
        }
    }

    private func toggle(_ gap: MonthKey) {
        withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
            if app.expandedMonthGaps.contains(gap) { app.expandedMonthGaps.remove(gap) } else { app.expandedMonthGaps.insert(gap) }
        }
    }
}

/// One row standing in for a folded empty period ("2017.06 – 2023.03 ⌄"). Tap opens it in place;
/// the same row stays above the opened months to fold them again.
struct FoldRow: View {
    let label: String
    let spoken: String
    let expanded: Bool
    let action: () -> Void
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        Button {
            action()
            // Keep VoiceOver on the row after it opens or folds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        } label: {
            HStack {
                Text(verbatim: label)
                    .font(.brand(14))
                    .foregroundStyle(Palette.primary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassCard(cornerRadius: 14, fill: Palette.surface.opacity(0.7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: spoken))
        .accessibilityValue(expanded ? Text("펼침") : Text("접힘"))
        .accessibilityHint(expanded ? Text("두 번 탭해 접어요.") : Text("두 번 탭해 펼쳐요."))
        .accessibilityFocused($focused)
    }
}

/// What a month cell shows: up to three fragments in entry order, then "+N".
enum MonthCellPreview {
    static let maxFragments = 3

    static func fragments(_ items: [RecordItem]) -> (shown: [RecordItem], overflow: String?) {
        let shown = Array(items.prefix(maxFragments))
        let rest = items.count - shown.count
        return (shown, rest > 0 ? "+\(rest)" : nil)
    }
}

struct MonthGrid: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let month: MonthKey

    var body: some View {
        let firstColumn = month.firstDay.column()
        VStack(alignment: .leading, spacing: 6) {
            // Month number above the weekday column of the 1st, outside the card.
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { column in
                    Group {
                        if column == firstColumn {
                            Text("\(month.month)")
                                .font(.brand(20, .medium))
                                .foregroundStyle(Palette.primary)
                                .fixedSize()
                                .accessibilityLabel("\(month.year)년 \(month.month)월")
                                .accessibilityAddTraits(.isHeader)
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(month.weeks().enumerated()), id: \.offset) { index, week in
                    if index > 0 { Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 8) }
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                cell(DayKey(year: month.year, month: month.month, day: day))
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 96)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .glassCard(cornerRadius: 22, fill: Palette.surface.opacity(0.78))
        }
    }

    private func cell(_ day: DayKey) -> some View {
        let items = store.items(on: day)
        let preview = MonthCellPreview.fragments(items)
        let selected = day == app.selectedDay
        return Button { app.openDay(day) } label: {
            VStack(spacing: 3) {
                Text("\(day.day)")
                    .font(.brand(14, items.isEmpty ? .regular : .semibold))
                    .foregroundStyle(selected ? Palette.focus : Palette.primary)
                    .padding(.top, 8)
                ForEach(preview.shown) { item in
                    Text(item.displayValue)
                        .font(.brand(item.kind == .emoji ? 11 : 9.5))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let overflow = preview.overflow {
                    Text(overflow)
                        .font(.brand(9.5))
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.horizontal, 2)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0x4A5A68).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.focus.opacity(0.45), lineWidth: 1))
                        .padding(3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pinchTarget(.day(day), in: .month)
        .accessibilityLabel(items.isEmpty ? day.label : "\(day.label), \(items.map(\.displayValue).joined(separator: ", "))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
