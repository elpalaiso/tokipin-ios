import SwiftUI

/// 월간 달력: every day of every month, scrolling vertically, with up to three entries per date.
struct MonthView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var visibleMonth: MonthKey?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DayKey.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.brand(12))
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
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
                .onAppear { proxy.scrollTo(app.focusedMonth, anchor: .top) }
                .onChange(of: app.selectedDay) { _, day in
                    withAnimation { proxy.scrollTo(day.monthKey, anchor: .top) }
                }
            }
        }
        .onChange(of: visibleMonth) { _, month in
            // Keep the header year in step with the scrolled month without moving selection.
            if let month { app.focusedMonth = month }
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

struct MonthGrid: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let month: MonthKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(month.month)")
                .font(.brand(20, .medium))
                .foregroundStyle(Palette.primary)
                .padding(.leading, 6)
                .accessibilityLabel("\(month.year)년 \(month.month)월")
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(month.weeks.enumerated()), id: \.offset) { index, week in
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
        let selected = day == app.selectedDay
        return Button { app.openDay(day) } label: {
            VStack(spacing: 3) {
                Text("\(day.day)")
                    .font(.brand(14, items.isEmpty ? .regular : .semibold))
                    .foregroundStyle(selected ? Palette.focus : Palette.primary)
                    .padding(.top, 8)
                ForEach(items.prefix(items.count > 3 ? 2 : 3)) { item in
                    Text(item.value)
                        .font(.brand(item.kind == .emoji ? 11 : 9.5))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
                if items.count > 3 {
                    Text("+\(items.count - 2)")
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
        .pinchTarget(.day(day))
        .accessibilityLabel(items.isEmpty ? day.label : "\(day.label), \(items.map(\.value).joined(separator: ", "))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
