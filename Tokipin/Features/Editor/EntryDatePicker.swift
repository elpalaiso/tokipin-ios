import SwiftUI

/// Date picker opened from the editor's centre date. ✕ restores everything; ✓ applies the date
/// only (the editor's own ✓ saves). Years and months can be chosen directly; nothing after this
/// month can become a new record's date.
struct EntryDatePicker: View {
    let current: DayKey
    let today: DayKey
    let onCancel: () -> Void
    let onConfirm: (DayKey) -> Void

    private enum Mode { case days, years, months }

    @State private var month: MonthKey
    @State private var candidate: DayKey?
    @State private var mode: Mode = .days

    init(current: DayKey, today: DayKey, onCancel: @escaping () -> Void, onConfirm: @escaping (DayKey) -> Void) {
        self.current = current
        self.today = today
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _month = State(initialValue: current.monthKey)
        _candidate = State(initialValue: current)
    }

    private var lastWritable: DayKey { CalendarRange.lastWritableDay(today: today) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                CircleIconButton(accessibilityLabel: "날짜 선택 취소", action: onCancel) {
                    Image(systemName: "xmark").resizable().scaledToFit().padding(3)
                }
                chip(String(month.year), label: "연도 \(String(month.year))", active: mode == .years) {
                    mode = mode == .years ? .days : .years
                }
                chip(mode == .months && candidate == nil ? "—" : "\(month.month)", label: "\(month.month)월", active: mode == .months) {
                    mode = mode == .months ? .days : .months
                }
                Spacer()
                CircleIconButton(accessibilityLabel: "이 날짜로 바꾸기", action: { if let candidate { onConfirm(candidate) } }) {
                    Image("IconCheck").renderingMode(.template).resizable().scaledToFit()
                }
                .disabled(candidate == nil)
                .opacity(candidate == nil ? 0.35 : 1)
            }
            switch mode {
            case .days: days
            case .years: years
            case .months: months
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .foregroundStyle(Palette.primary)
    }

    private func chip(_ text: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(verbatim: text).font(.brand(14))
                Image(systemName: active ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text("두 번 탭해 골라요."))
    }

    // MARK: Days

    private var days: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(DayKey.orderedWeekdaySymbols(), id: \.self) { symbol in
                    Text(symbol).font(.brand(12)).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(month.weeks().enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, number in
                        if let number {
                            dayCell(DayKey(year: month.year, month: month.month, day: number))
                        } else {
                            Color.clear.frame(height: 40).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            // Swipe the grid for the next/previous month.
            let next = month.adding(months: value.translation.width < 0 ? 1 : -1)
            if next <= today.monthKey { month = next }
        })
    }

    private func dayCell(_ day: DayKey) -> some View {
        let enabled = day <= lastWritable
        let chosen = day == candidate
        return Button { candidate = day } label: {
            Text("\(day.day)")
                .font(.brand(15, chosen ? .semibold : .regular))
                .foregroundStyle(chosen ? Palette.onFocus : Palette.primary)
                .frame(width: 36, height: 36)
                .background(chosen ? Palette.focus : .clear, in: Circle())
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(Text(verbatim: day.label))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    // MARK: Years and months

    private var years: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(1970...today.year, id: \.self) { year in
                        optionButton(String(year), selected: year == month.year, enabled: true) {
                            month = MonthKey(year: year, month: min(month.month, year == today.year ? today.month : 12))
                            candidate = nil
                            mode = .months
                        }
                        .id(year)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(month.year, anchor: .center) }
        }
    }

    private var months: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(1...12, id: \.self) { number in
                let key = MonthKey(year: month.year, month: number)
                optionButton("\(number)", selected: number == month.month && candidate != nil, enabled: key <= today.monthKey) {
                    month = key
                    candidate = nil
                    mode = .days
                }
            }
        }
    }

    private func optionButton(_ text: String, selected: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: text)
                .font(.brand(15, selected ? .semibold : .regular))
                .foregroundStyle(selected ? Palette.onFocus : Palette.primary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? Palette.focus : Color.white.opacity(0.06), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
