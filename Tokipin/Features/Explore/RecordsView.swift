import SwiftUI

/// 기록한 날: only days with entries, as a vertical bento grouped by month.
struct RecordsView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let onLongPress: (DayKey) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                    ForEach(months, id: \.self) { month in
                        section(month)
                            .id(month)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Keep the anchored date in view (pinch, back from 일간); else the month header.
                if store.records[app.selectedDay] != nil, app.selectedDay.monthKey == app.focusedMonth {
                    proxy.scrollTo(app.selectedDay, anchor: .center)
                } else {
                    proxy.scrollTo(app.focusedMonth, anchor: .top)
                }
            }
            .onChange(of: app.focusedMonth) { _, month in
                withAnimation { proxy.scrollTo(month, anchor: .top) }
            }
        }
    }

    /// Months with records, plus the focused month so an empty month still opens.
    private var months: [MonthKey] {
        var set = Set(store.records.keys.map(\.monthKey))
        set.insert(app.focusedMonth)
        return set.sorted(by: >)
    }

    @ViewBuilder
    private func section(_ month: MonthKey) -> some View {
        let days = store.days(in: month)
        Text(month.dotted)
            .font(.brand(19, .medium))
            .foregroundStyle(Palette.primary)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
        if days.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("이달에 남긴 기록이 없어요.")
                    .font(.brand(15))
                    .foregroundStyle(Palette.secondary)
                OutlineCapsuleButton(title: "달력 보기") { app.setLevel(.month) }
            }
            .padding(.vertical, 8)
        } else {
            ForEach(Self.rows(days), id: \.first) { row in
                if row.count == 1 {
                    card(row[0], large: true)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row, id: \.self) { card($0, large: false) }
                        if row.count == 1 { Spacer() }
                    }
                }
            }
        }
    }

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

    private func card(_ day: DayKey, large: Bool) -> some View {
        let items = store.items(on: day)
        let title = items.first { $0.kind != .emoji } ?? items.first
        let rest = items.filter { $0.id != title?.id }
        let emoji = rest.first { $0.kind == .emoji }
        let detail = rest.filter { $0.kind != .emoji }.map(\.value)

        return VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%02d / %@", day.day, day.weekdaySymbol))
                .font(.brand(13))
                .foregroundStyle(Palette.secondary)
            Text(title?.value ?? "")
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
        .pinchTarget(.day(day))
        .id(day)
        .onTapGesture { app.openDay(day) }
        .onLongPressGesture(minimumDuration: 0.45) {
            Haptics.selection()
            onLongPress(day)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.label), \(items.map(\.value).joined(separator: ", "))")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "이날 기록 삭제") { onLongPress(day) }
    }
}
