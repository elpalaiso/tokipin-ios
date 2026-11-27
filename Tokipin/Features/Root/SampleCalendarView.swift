import Accessibility
import SwiftUI

struct SampleCalendarView: View {
    let startJournal: () -> Void
    @State private var sample = SampleCalendar()
    @State private var practiceOrigin: DayKey?
    @State private var notice: UUID?
    @AccessibilityFocusState private var headerFocused: Bool
    private let sage = Color(hex: 0xD8E6CD)
    private let ink = Color(hex: 0x203127)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("예시 달력").font(.brand(17, .semibold)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button(action: startJournal) {
                    Text("내 기록 시작").font(.brand(15, .semibold)).multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 6).frame(minHeight: 44)
                        .foregroundStyle(ink).background(sage, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sample.start")
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            navigation
            switch sample.page {
            case .month:
                calendar
            case .day(let day):
                dayPage(day)
            case .practice:
                practicePage
            }
        }
        .foregroundStyle(Palette.primary)
        .onChange(of: sample.page) { headerFocused = true }
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { notice = nil }
        }
        .accessibilityAction(.escape) { goBack() }
    }

    private var navigation: some View {
        HStack(spacing: 4) {
            switch sample.page {
            case .month:
                monthButton(-1)
                Spacer()
                Text(verbatim: TimeRules.displayLocale.language.languageCode?.identifier == "ko" ? sample.month.dotted : sample.month.spokenLabel)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text(verbatim: sample.month.spokenLabel))
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($headerFocused)
                Spacer()
                monthButton(1)
            case .day(let day):
                dayButton(day, -1)
                Spacer()
                Button(action: goBack) {
                    Label(day.label, systemImage: "calendar")
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain).accessibilityLabel("월간 달력으로")
                .accessibilityValue(Text(verbatim: day.spokenLabel))
                .accessibilityFocused($headerFocused)
                .accessibilityIdentifier("sample.calendar")
                Spacer()
                dayButton(day, 1)
            case .practice(let day):
                Button(action: goBack) { arrow(-1) }
                    .accessibilityLabel("뒤로")
                Spacer()
                Text(verbatim: day.label).multilineTextAlignment(.center)
                    .accessibilityLabel(Text(verbatim: day.spokenLabel))
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($headerFocused)
                Spacer()
                Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            }
        }
        .font(.brand(21, .medium)).padding(.horizontal, 16).padding(.vertical, 6)
        .buttonStyle(.plain)
    }

    private func arrow(_ direction: Int) -> some View {
        Image(systemName: direction < 0 ? "chevron.backward" : "chevron.forward")
            .font(.system(size: 19, weight: .medium)).frame(width: 44, height: 44).contentShape(Rectangle())
    }

    private func monthButton(_ offset: Int) -> some View {
        let month = sample.month.adding(months: offset)
        let available = sample.months.contains(month)
        return Button { sample.month = month; notice = nil } label: { arrow(offset) }
            .accessibilityLabel(Text(verbatim: month.spokenLabel))
            .accessibilityIdentifier(offset < 0 ? "sample.previous" : "sample.next")
            .disabled(!available).opacity(available ? 1 : 0.3)
    }

    private func dayButton(_ day: DayKey, _ offset: Int) -> some View {
        let target = day.adding(days: offset)
        let available = sample.months.contains(target.monthKey)
        return Button { openDay(target) } label: { arrow(offset) }
            .accessibilityLabel(offset < 0 ? Text("이전 날") : Text("다음 날"))
            .disabled(!available).opacity(available ? 1 : 0.3)
    }

    private var calendar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(DayKey.orderedWeekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol).font(.brand(12)).frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(Palette.secondary).padding(.horizontal, 12).accessibilityHidden(true)
            GeometryReader { viewport in
                ScrollViewReader { reader in
                    ScrollView {
                        CalendarMonthCard(month: sample.month) { day in
                            let target = sample.guides && day == sample.featured
                            MonthDateCell(day: day, items: sample.items(on: day), selected: day == sample.lastSaved) {
                                openDay(day)
                            }
                            .overlay {
                                if target {
                                    RoundedRectangle(cornerRadius: 8).strokeBorder(sage, lineWidth: 2)
                                        .padding(2).allowsHitTesting(false)
                                }
                            }
                            .accessibilityIdentifier(target ? "sample.featured" : "sample.day.\(day.day)")
                            .id(day)
                        } afterWeek: { week in
                            if sample.guides && week.contains(sample.featured.day) {
                                guide("날짜를 눌러 그날의 기록을 열어 보세요.")
                                    .padding(.vertical, 2).padding(.horizontal, 8)
                                    .id("sample.monthGuide")
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .task(id: viewport.size.height) {
                        // Wait for the calendar to lay out before revealing a date on a short screen.
                        await Task.yield()
                        if let day = sample.lastSaved, day.monthKey == sample.month {
                            reader.scrollTo(day, anchor: .center)
                        } else if sample.guides {
                            // Bottom anchoring clamps to the top if the guide already fits.
                            reader.scrollTo("sample.monthGuide", anchor: .bottom)
                        }
                    }
                    .id(sample.month)
                }
            }
            if notice != nil {
                Text("예시 달력에 표시했어요.").font(.brand(14))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 8)
            }
        }
    }

    private func dayPage(_ day: DayKey) -> some View {
        let canPractice = sample.practiceDate(from: day) != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let items = sample.items(on: day)
                if items.isEmpty {
                    Text("이날 남긴 기록이 없어요.").foregroundStyle(Palette.secondary).padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            DayRecordRow(item: item, showsWordIcon: true)
                        }
                    }
                }
                Button {
                    practiceOrigin = day
                    sample.beginPractice(from: day)
                } label: {
                    Text("예시 이모지 남기기").font(.brand(15, .medium))
                        .padding(.horizontal, 16).padding(.vertical, 6).frame(minHeight: 44)
                        .background(sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(sage.opacity(sample.guides ? 1 : 0.45),
                                                                               lineWidth: sample.guides ? 2 : 1))
                }
                .buttonStyle(.plain).accessibilityIdentifier("sample.practice")
                .disabled(!canPractice)
                .opacity(canPractice ? 1 : 0.4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 22)
        }
    }

    private var practicePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sample.guides {
                    guide("이모지를 골라 예시 달력에 남겨 보세요.")
                        .opacity(sample.selectedEmoji == nil ? 1 : 0)
                        .allowsHitTesting(sample.selectedEmoji == nil)
                        .accessibilityHidden(sample.selectedEmoji != nil)
                }
                HStack(alignment: .center, spacing: 10) {
                    ForEach(SampleCalendar.emoji, id: \.self) { emoji in
                        let selected = sample.selectedEmoji == emoji
                        let suggested = sample.guides && sample.selectedEmoji == nil && emoji == SampleCalendar.emoji.first
                        let outlined = selected || suggested
                        Button { sample.selectedEmoji = emoji } label: {
                            Text(verbatim: emoji).font(.brand(26))
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .frame(minWidth: 44, maxWidth: 80)
                                .frame(height: max(60, BrandFont.uiFont(26).lineHeight + 12))
                                .background(sage.opacity(selected ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(sage.opacity(outlined ? 1 : 0.32), lineWidth: outlined ? 2 : 1))
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                HStack(alignment: .center, spacing: 6) {
                    if sample.guides, sample.selectedEmoji != nil {
                        guide("체크 표시를 눌러 저장해요.")
                    }
                    Spacer(minLength: 0)
                    Button {
                        sample.savePractice()
                        notice = UUID()
                        AccessibilityNotification.Announcement(String(localized: "예시 달력에 표시했어요.")).post()
                    } label: {
                        Image(systemName: "checkmark").font(.system(size: 19, weight: .semibold))
                            .frame(width: 44, height: 44).foregroundStyle(ink)
                            .background(sage, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).disabled(sample.selectedEmoji == nil)
                    .opacity(sample.selectedEmoji == nil ? 0.35 : 1).accessibilityLabel("기록 저장")
                    .accessibilityIdentifier("sample.save")
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 24)
        }
    }

    private func guide(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 0) {
            Text(title).font(.brand(13, .medium)).padding(.leading, 12).padding(.vertical, 6)
            Button { sample.guides = false } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("탐색 안내 닫기")
        }
        .foregroundStyle(ink).background(sage, in: RoundedRectangle(cornerRadius: 12))
    }

    private func openDay(_ day: DayKey) {
        sample.month = day.monthKey
        sample.page = .day(day)
        notice = nil
    }

    private func goBack() {
        switch sample.page {
        case .month: break
        case .day: sample.page = .month
        case .practice(let day): openDay(practiceOrigin ?? day)
        }
    }
}
