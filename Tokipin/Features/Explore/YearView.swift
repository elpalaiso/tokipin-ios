import SwiftUI

/// 연간: years continue vertically, each with twelve small months.
struct YearView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var visibleYear: Int?
    @State private var didInitialScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(years, id: \.self) { year in
                        yearBlock(year).id(year)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $visibleYear, anchor: .top)
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                proxy.scrollTo(app.focusedMonth.year, anchor: .top)
            }
            .onChange(of: app.reveal) { _, request in
                guard let request, app.level == .year else { return }
                withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                    proxy.scrollTo(request.day.year, anchor: .top)
                }
            }
            .onChange(of: visibleYear) { _, year in
                // Only the visible year changes while scrolling.
                if let year, app.level == .year, year != app.focusedMonth.year {
                    app.focusedMonth = MonthKey(year: year, month: app.focusedMonth.month)
                }
            }
        }
    }

    private var years: [Int] {
        let today = DayKey.today.year
        let earliest = store.records.keys.min()?.year ?? today
        return Array(min(earliest, today - 1)...max(today, app.selectedDay.year) + 1)
    }

    private func yearBlock(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(year))
                .font(.brand(30, .medium))
                .foregroundStyle(Palette.primary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 16) {
                ForEach(1...12, id: \.self) { month in
                    MiniMonth(month: MonthKey(year: year, month: month))
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22, fill: Palette.surface.opacity(0.78))
    }
}

struct MiniMonth: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let month: MonthKey

    var body: some View {
        let recorded = Set(store.days(in: month).map(\.day))
        let isFocused = month == app.selectedDay.monthKey
        Button {
            // Keep the selected day if it is in this month; otherwise its latest record or the 1st.
            let day = month == app.selectedDay.monthKey ? app.selectedDay
                : recorded.max().map { DayKey(year: month.year, month: month.month, day: $0) } ?? month.firstDay
            app.navigate(to: day, level: .month)
            app.focusedMonth = month
            app.requestReveal(day)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(month.month)")
                    .font(.brand(15, .medium))
                    .foregroundStyle(Palette.primary)
                Grid(horizontalSpacing: 0, verticalSpacing: 1) {
                    ForEach(Array(month.weeks().enumerated()), id: \.offset) { _, week in
                        GridRow {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                Text(day.map(String.init) ?? "")
                                    .font(.brand(7, day.map { recorded.contains($0) } == true ? .bold : .regular))
                                    .foregroundStyle(day.map { recorded.contains($0) } == true ? Palette.primary : Palette.secondary.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                                    .overlay(alignment: .bottom) {
                                        if let day, recorded.contains(day) {
                                            Circle().fill(Palette.focus).frame(width: 2.5, height: 2.5).offset(y: 2.5)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background {
                if isFocused {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x4A5A68).opacity(0.8))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.focus.opacity(0.4), lineWidth: 1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pinchTarget(.month(month), in: .year)
        .accessibilityLabel("\(month.month)월, 기록한 날 \(recorded.count)일")
    }
}
