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
                        ForEach(months, id: \.self) { month in
                            MonthGrid(month: month).id(month)
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
                    proxy.scrollTo(app.focusedMonth, anchor: .top)
                }
                .onChange(of: app.reveal) { _, request in
                    guard let request, app.level == .month else { return }
                    withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                        proxy.scrollTo(request.day.monthKey, anchor: UnitPoint(x: 0.5, y: request.anchorY ?? 0))
                    }
                }
            }
        }
        .onChange(of: visibleMonth) { _, month in
            // Scrolling only changes the visible period; the selected day stays (UX v0.1 §2).
            if let month, app.level == .month { app.focusedMonth = month }
        }
    }

    private var months: [MonthKey] {
        let today = DayKey.today.monthKey
        let earliest = store.records.keys.min()?.monthKey ?? today
        let first = min(MonthKey(year: earliest.year, month: 1), MonthKey(year: today.year - 1, month: 1))
        let last = MonthKey(year: max(today.year, app.selectedDay.year) + 1, month: 12)
        var result: [MonthKey] = []
        var cursor = first
        while cursor <= last {
            result.append(cursor)
            cursor = cursor.adding(months: 1)
        }
        return result
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
