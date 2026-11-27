import Accessibility
import SwiftUI

/// A real editor and four real archive views operate on a private, memory-only journal.
@MainActor @Observable
final class SampleTour {
    enum Panel { case leaveGuide, invitation }
    enum Cue: String {
        case daySwipe, dayZoom, recordsSwipe, recordsZoom, monthScroll, monthZoom, yearOpen, pickDay

        var title: LocalizedStringKey {
            switch self {
            case .daySwipe: "날짜를 좌우로 쓸어 전날과 다음 날을 둘러보세요."
            case .dayZoom: "두 손가락을 모으면 기록한 날만 보여요."
            case .recordsSwipe: "위의 월 숫자를 누르거나 좌우로 밀어 다른 달을 보세요."
            case .recordsZoom: "두 손가락을 모으면 월간 달력이 보여요."
            case .monthScroll: "위아래로 스크롤해 다른 달을 둘러보세요."
            case .monthZoom: "두 손가락을 모으면 한 해가 보여요."
            case .yearOpen: "월을 누르거나 두 손가락을 벌려 한 달을 펼치세요."
            case .pickDay: "날짜를 눌러 그날의 기록을 열어 보세요."
            }
        }
        static func first(for level: ExploreLevel) -> Self {
            switch level {
            case .day: .daySwipe
            case .records: .recordsSwipe
            case .month: .monthScroll
            case .year: .yearOpen
            }
        }
    }

    let store: RecordStore
    let app = AppModel()
    var guided = true
    var cue = Cue.daySwipe
    var panel: Panel?
    private var savedOnce = false
    var notice: String?

    init(today: DayKey = .today) {
        let words = SampleGenerator.localizedWords
        store = RecordStore(sample: SampleGenerator.archive(today: today, vocabulary: words))
        app.today = today
        app.navigate(to: today, level: .day, haptic: false)
        if store.items(on: today).isEmpty {
            let starter = SampleGenerator.items(for: today, vocabulary: words, starter: true)
            store.updateDraft(Draft(day: today, items: starter, kind: .word, raw: "", changed: false), for: today)
        }
        app.openEditor(for: today, keyboard: false)
    }

    func replay() {
        guided = true
        cue = .first(for: app.level)
    }

    func didSave(_ items: [RecordItem]) {
        let message: String
        if !items.isEmpty && !savedOnce {
            savedOnce = true
            message = String(localized: "첫 기록을 남겼어요.")
        } else {
            message = items.isEmpty ? String(localized: "이날의 기록을 비웠어요.") : String(localized: "기록을 저장했어요.")
        }
        notice = message
        AccessibilityNotification.Announcement(message).post()
        cue = .daySwipe
    }

    func changedLevel(from old: ExploreLevel, to new: ExploreLevel) {
        guard guided, app.editorDay == nil else { return }
        cue = old == .year && new == .month ? .pickDay : .first(for: new)
    }

    func openCalendarDay(_ day: DayKey) {
        let completesGuide = guided && cue == .pickDay && app.level == .month
        app.openDay(day)
        if completesGuide {
            guided = false
            panel = .invitation
        }
    }

    func changedDay() {
        if guided, app.editorDay == nil, app.level == .day, cue == .daySwipe { cue = .dayZoom }
    }

    func changedRecordsMonth() {
        if guided, app.level == .records, cue == .recordsSwipe { cue = .recordsZoom }
    }

    func scrolledMonth() {
        if guided, app.level == .month, cue == .monthScroll { cue = .monthZoom }
    }

    /// The alternative to each gesture invokes that gesture's semantic navigation action.
    func nextInArchive() {
        guard guided, panel == nil, app.editorDay == nil else { return }
        switch cue {
        case .daySwipe:
            app.select(app.selectedDay.adding(days: -1))
            changedDay()
        case .dayZoom:
            app.setLevel(.records)
        case .recordsSwipe:
            let months = store.recordedMonths.sorted()
            if let index = months.firstIndex(of: app.recordsMonth), months.count > 1 {
                app.commitRecordsMonth(months[index > 0 ? index - 1 : 1])
            }
            changedRecordsMonth()
        case .recordsZoom:
            let day = store.days(in: app.recordsMonth).first ?? app.recordsMonth.firstDay
            app.navigate(to: day, level: .month)
            app.requestReveal(day)
        case .monthScroll:
            let first = CalendarRange.firstMonth(today: app.today, earliestRecord: store.earliestDay)
            let target = app.focusedMonth.adding(months: app.focusedMonth <= first ? 1 : -1)
            app.focusedMonth = target
            app.requestReveal(store.days(in: target).first ?? target.firstDay)
            scrolledMonth()
        case .monthZoom:
            let day = store.days(in: app.focusedMonth).first ?? app.focusedMonth.firstDay
            app.navigate(to: day, level: .year)
            app.requestReveal(day)
        case .yearOpen:
            let month = app.focusedMonth
            let day = month == app.selectedDay.monthKey ? app.selectedDay : store.days(in: month).first ?? month.firstDay
            app.navigate(to: day, level: .month)
            app.requestReveal(day)
        case .pickDay:
            openCalendarDay(store.days(in: app.focusedMonth).first ?? app.focusedMonth.firstDay)
        }
    }
}

struct SampleTourHost: View {
    @Bindable var tour: SampleTour
    let startJournal: () -> Void
    @State private var confirmed = false

    var body: some View {
        Group {
            if let day = tour.app.editorDay {
                EditorView(day: day, focusItem: tour.app.editorFocusItem, startsWithKeyboard: tour.app.editorStartsWithKeyboard)
                    .id(day)
            } else {
                ExploreView()
            }
        }
        .accessibilityHidden(tour.panel != nil)
        .environment(tour.store).environment(tour.app).environment(tour)
        .sheet(isPresented: Binding(get: { tour.panel != nil }, set: { if !$0 { tour.panel = nil } }), onDismiss: {
            if confirmed { confirmed = false; startJournal() }
        }) {
            SampleTourDecision(tour: tour) {
                confirmed = true
                tour.panel = nil
            }
        }
    }
}

private let tourPaper = Color(hex: 0xD8E6CD)
private let tourInk = Color(hex: 0x203127)

struct TourRail: View {
    let tour: SampleTour
    let editor: Bool
    let replay: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            if tour.panel != nil {
                Color.clear.frame(width: 1, height: 44).accessibilityHidden(true)
            } else if tour.guided {
                Button("다음", action: next)
                    .accessibilityIdentifier("trial.next")
                    .accessibilityHint("안내 동작 실행")
            } else {
                Button(action: replay) {
                    Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                }
                .accessibilityLabel(editor ? Text("입력 안내 다시 보기") : Text("탐색 안내 다시 보기"))
                Button("시작") { tour.panel = .invitation }.accessibilityIdentifier("trial.start")
            }
        }
        .buttonStyle(TrialAction()).padding(.horizontal, 14).padding(.vertical, 2)
    }
}

private struct TrialAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.brand(15, .semibold)).foregroundStyle(tourInk)
            .padding(.horizontal, 14).padding(.vertical, 3).frame(minHeight: 44)
            .background(tourPaper, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct TourHint: View {
    let title: LocalizedStringKey
    let editor: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Text(title).font(.brand(13, .medium)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(editor ? Text("입력 안내 닫기") : Text("탐색 안내 닫기"))
        }
        .padding(.leading, 12).foregroundStyle(tourInk)
        .background(tourPaper, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

private struct SampleTourDecision: View {
    let tour: SampleTour
    let start: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button { tour.panel = nil } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("닫기")
                }
                if tour.panel == .invitation {
                    Text("이제 나만의 기록을 쌓아가 볼까요?").font(.brand(23, .medium)).accessibilityAddTraits(.isHeader)
                    Button(action: start) { Text("시작").frame(maxWidth: .infinity) }.buttonStyle(TrialAction())
                        .accessibilityIdentifier("trial.confirm")
                } else {
                    Button { tour.guided = false; tour.panel = nil } label: {
                        Text("계속 둘러보기").frame(maxWidth: .infinity)
                    }.buttonStyle(TrialAction())
                    Button("시작") { tour.guided = false; tour.panel = .invitation }
                        .font(.brand(16, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }
        .foregroundStyle(Palette.primary)
        .presentationDetents(typeSize.isAccessibilitySize ? [.medium, .large] : [.height(240)])
        .accessibilityAddTraits(.isModal)
        .presentationBackgroundInteraction(.disabled)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.surface)
    }
}

extension View {
    @ViewBuilder
    func trialHighlight(_ active: Bool, radius: CGFloat = 10) -> some View {
        // Keep the control's identity, especially while UIKit is delivering text or composing.
        overlay {
            if active {
                RoundedRectangle(cornerRadius: radius).strokeBorder(tourPaper, lineWidth: 2)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
