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
                    ForEach(sections, id: \.id) { section in
                        switch section {
                        case .year(let year):
                            yearBlock(year).id(year)
                        case .gap(let first, let last):
                            FoldRow(label: first == last ? String(first) : "\(first) – \(last)",
                                    spoken: first == last ? String(localized: "\(String(first))년, 기록 없는 해")
                                        : String(localized: "\(String(first))년부터 \(String(last))년까지 기록 없는 \(last - first + 1)년"),
                                    expanded: app.expandedYearGaps.contains(first)) {
                                withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                                    if app.expandedYearGaps.contains(first) { app.expandedYearGaps.remove(first) } else { app.expandedYearGaps.insert(first) }
                                }
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
            .scrollPosition(id: $visibleYear, anchor: .top)
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                openGap(for: app.focusedMonth.year)
                proxy.scrollTo(clamped(app.focusedMonth.year), anchor: .top)
            }
            .onChange(of: app.reveal) { _, request in
                guard let request, app.level == .year else { return }
                let year = clamped(request.day.year)
                openGap(for: year)
                Task { @MainActor in
                    withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
                        proxy.scrollTo(year, anchor: .top)
                    }
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

    private var recordedYears: Set<Int> { store.recordedYears }

    private var sections: [CalendarRange.YearSection] {
        CalendarRange.yearSections(today: app.today, recordedYears: recordedYears,
                                   earliestRecord: store.earliestDay, expanded: app.expandedYearGaps)
    }

    private func clamped(_ year: Int) -> Int {
        let first = CalendarRange.firstMonth(today: app.today, earliestRecord: store.earliestDay).year
        return min(max(year, first), app.today.year)
    }

    private func openGap(for year: Int) {
        if let gap = CalendarRange.yearGaps(today: app.today, recordedYears: recordedYears, earliestRecord: store.earliestDay)
            .first(where: { year >= $0.first && year <= $0.last }) {
            app.expandedYearGaps.insert(gap.first)
        }
    }

    private func yearBlock(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // ③ Summary dot: this year holds at least one record. It adds to, never replaces,
            // the selected-month focus and the per-day dots below.
            HStack(alignment: .top, spacing: 5) {
                Text(String(year))
                    .font(.brand(30, .medium))
                    .foregroundStyle(Palette.primary)
                if recordedYears.contains(year) { SummaryDot(size: 6).padding(.top, 8) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(recordedYears.contains(year) ? Text("\(String(year))년, 기록 있음") : Text("\(String(year))년"))
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 16) {
                ForEach(1...12, id: \.self) { month in
                    MiniMonth(month: MonthKey(year: year, month: month))
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22, fill: Palette.surface.opacity(0.78))
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Phones: 3×4. Wide screens: 4×3 or 6×2.
    private var columns: Int { sizeClass == .regular ? 4 : 3 }
}

/// Small dot next to a year or month title meaning "has records".
struct SummaryDot: View {
    var size: CGFloat = 4
    var body: some View {
        Circle().fill(Palette.focus).frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct MiniMonth: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    let month: MonthKey

    var body: some View {
        let recorded = Set(store.days(in: month).map(\.day))
        let isFocused = month == app.selectedDay.monthKey
        let inRange = CalendarRange.contains(month, today: app.today, earliestRecord: store.earliestDay)
        Button {
            // Keep the selected day if it is in this month; otherwise its latest record or the 1st.
            let day = month == app.selectedDay.monthKey ? app.selectedDay
                : recorded.max().map { DayKey(year: month.year, month: month.month, day: $0) } ?? month.firstDay
            app.navigate(to: day, level: .month)
            app.focusedMonth = month
            app.requestReveal(day)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 3) {
                    Text("\(month.month)")
                        .font(.brand(15, .medium))
                        .foregroundStyle(Palette.primary)
                    if !recorded.isEmpty { SummaryDot(size: 4).padding(.top, 5) }
                }
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
        // Before the first explorable month or after this month: dimmed and inactive.
        .disabled(!inRange)
        .opacity(inRange ? 1 : 0.35)
        .modifier(PinchTargetIf(enabled: inRange, target: .month(month)))
        .accessibilityLabel(inRange ? Text("\(month.month)월, 기록한 날 \(recorded.count)일") : Text("\(month.month)월, 범위 밖"))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}

private struct PinchTargetIf: ViewModifier {
    let enabled: Bool
    let target: PinchTarget
    func body(content: Content) -> some View {
        if enabled { content.pinchTarget(target, in: .year) } else { content }
    }
}
