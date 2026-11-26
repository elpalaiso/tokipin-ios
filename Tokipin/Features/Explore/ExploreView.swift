import SwiftUI

struct PendingUndo: Identifiable {
    let id = UUID()
    let message: String
    let undo: () -> Void
}

/// Home: the four explore levels with a shared header, "오늘" and "+".
struct ExploreView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var pendingUndo: PendingUndo?
    @State private var dayToDelete: DayKey?
    @State private var errorMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Live pinch scale of the current view while two fingers are down.
    @State private var pinchScale: CGFloat = 1
    /// Date or month under the first valid two-finger midpoint; kept for the whole pinch.
    @State private var pinchAnchor: (target: PinchTarget, frame: CGRect)?
    /// Point the zoom grows from, relative to the content area.
    @State private var zoomAnchor: UnitPoint = .center
    /// Per-level scale used for the settle animation after a level change.
    @State private var layerScale: [ExploreLevel: CGFloat] = [:]
    @State private var contentFrame: CGRect = .zero
    @State private var pinchActive = false
    @State private var headerWidth: CGFloat = 390
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var app = app
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { contentFrame = $0 }
            }
            .background(
                PinchCatcher(
                    isEnabled: app.editorDay == nil && !app.isSearching && !app.isShowingSettings,
                    onBegin: beginPinch,
                    onChange: { scale in if pinchActive { pinchScale = scale } },
                    onEnd: finishPinch
                )
            )

            if store.isEmpty && app.level == .records {
                EmptyHomeRabbit()
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay {
            if app.isSearching {
                SearchView()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $app.isShowingSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: 0x2E3832))
                .presentationCornerRadius(28)
        }
        .confirmationDialog(dayToDelete?.label ?? "", isPresented: Binding(
            get: { dayToDelete != nil }, set: { if !$0 { dayToDelete = nil } }
        ), titleVisibility: .visible, presenting: dayToDelete) { day in
            Button("이날 기록 \(store.items(on: day).count)개 삭제", role: .destructive) { deleteDay(day) }
            Button("취소", role: .cancel) {}
        }
        .alert("저장하지 못했어요", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .animation(.easeOut(duration: 0.2), value: pendingUndo?.id)
        .animation(.easeOut(duration: 0.18), value: app.isSearching)
    }

    // MARK: Header

    /// The date title sits on the screen's centre line (safe area included), not between the
    /// buttons; back, search-result return and the menus stay separate 44pt targets (v0.3 §1).
    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Large text: the title takes its own line under the buttons instead of shrinking.
                VStack(spacing: 2) {
                    buttonsRow.frame(height: 56)
                    titleView.frame(maxWidth: .infinity).padding(.bottom, 6)
                }
            } else {
                ZStack {
                    titleView
                    buttonsRow
                }
                .frame(height: 56)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { headerWidth = $0 }
    }

    @ViewBuilder
    private var titleView: some View {
            if let title = headerTitle {
            Text(verbatim: title)
                .font(.brand(22, .medium, relativeTo: .title2))
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // Never under the side buttons: at most the width left between the widest side.
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : max(headerWidth - 2 * sideReserve, 60))
                .accessibilityLabel(Text(verbatim: headerSpokenTitle ?? title))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var buttonsRow: some View {
            HStack(spacing: 0) {
                if let parent = parentLevel {
                    Button {
                        app.searchHighlight = nil
                        if app.level == .day {
                            app.closeDay()
                        } else {
                            app.setLevel(parent, haptic: false)
                            app.requestReveal(app.selectedDay)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(backLabel(parent)))
                }
                Spacer()
                // Adding and editing live in the bottom +/pencil; the menu keeps deleting a whole day.
                if app.level == .day && !store.items(on: app.selectedDay).isEmpty {
                    Menu {
                        Button(role: .destructive) { dayToDelete = app.selectedDay } label: {
                            Label("이날 기록 삭제", systemImage: "trash")
                        }
                    } label: { HeaderIcon(systemName: "ellipsis") }
                    .accessibilityLabel("이날 더보기")
                }
                if app.searchHighlight != nil && app.level == .day {
                    // Icon-only so the centred title never collides with it.
                    Button { app.isSearching = true } label: { HeaderIcon(systemName: "text.magnifyingglass") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("검색 결과로 돌아가기")
                } else {
                    Button { app.isSearching = true } label: { HeaderIcon(systemName: "magnifyingglass") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("기록 검색")
                }
                viewMenu
            }
    }

    /// Widest side of the header row (three 44pt buttons plus padding).
    private var sideReserve: CGFloat { 10 + 44 * 3 }

    private func backLabel(_ parent: ExploreLevel) -> String {
        switch parent {
        case .year: String(localized: "연간 달력으로")
        case .month: String(localized: "월간 달력으로")
        case .records: String(localized: "기록한 날로")
        case .day: String(localized: "일간으로")
        }
    }

    private var viewMenu: some View {
        Menu {
            Picker("탐색 보기", selection: Binding(get: { app.level }, set: {
                app.searchHighlight = nil
                app.setLevel($0)
                app.requestReveal(app.selectedDay)
            })) {
                ForEach(ExploreLevel.allCases.reversed()) { level in
                    Label(level.title, systemImage: level.systemImage).tag(level)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button { app.isShowingSettings = true } label: { Label("설정", systemImage: "gearshape") }
        } label: {
            HeaderIcon(systemName: "square.on.square")
        }
        .accessibilityLabel("탐색 보기, \(app.level.title)")
    }

    private var parentLevel: ExploreLevel? {
        switch app.level {
        case .day: app.dayReturnLevel
        case .records, .month: .year
        case .year: nil
        }
    }

    /// 일간 "2017.05", 기록한 날 the committed month's year, 월간 the visible month's year,
    /// 연간 none (each year block carries its own).
    private var headerTitle: String? {
        switch app.level {
        case .day: DateHeader.day(app.selectedDay)
        case .records: DateHeader.year(app.recordsMonth)
        case .month: DateHeader.year(app.focusedMonth)
        case .year: nil
        }
    }

    private var headerSpokenTitle: String? {
        switch app.level {
        case .day: app.selectedDay.monthKey.spokenLabel
        case .records: String(localized: "\(String(app.recordsMonth.year))년")
        case .month: String(localized: "\(String(app.focusedMonth.year))년")
        case .year: nil
        }
    }

    // MARK: Content

    /// All four views stay alive so each keeps its own scroll position when you come back
    /// (UX v0.1 §2: closing a day returns to the view and place it was opened from).
    private var content: some View {
        ZStack {
            layer(.year) { YearView() }
            layer(.month) { MonthView() }
            layer(.records) {
                if store.isEmpty {
                    EmptyHome()
                } else {
                    RecordsView(onLongPress: { dayToDelete = $0 })
                }
            }
            layer(.day) { DayView(onUndo: showUndo, onError: showError) }
        }
    }

    private func layer<Content: View>(_ level: ExploreLevel, @ViewBuilder _ content: () -> Content) -> some View {
        let active = app.level == level
        let liveScale = active && pinchActive && !reduceMotion ? min(max(pinchScale, 0.5), 2.0) : 1
        return content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scaleEffect(liveScale * (layerScale[level] ?? 1), anchor: zoomAnchor)
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let pendingUndo {
                UndoToast(message: pendingUndo.message) {
                    pendingUndo.undo()
                    self.pendingUndo = nil
                }
            }
            if !(store.isEmpty && app.level == .records) {
                HStack {
                    FloatingCapsuleButton(title: "오늘") { app.goToday() }
                    Spacer()
                    if app.level == .day && !store.items(on: app.selectedDay).isEmpty {
                        FloatingAddButton(systemImage: "pencil", accessibilityLabel: "이날 기록 편집") {
                            app.openEditor(for: app.selectedDay, keyboard: false)
                        }
                    } else {
                        FloatingAddButton { openAdd() }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: Pinch (UX v0.1 §2)

    private func beginPinch(at point: CGPoint) {
        // Only pinches that start on the calendar content count (not header or bottom bar).
        guard contentFrame.contains(point) else { pinchActive = false; return }
        pinchActive = true
        app.isPinching = true
        pinchScale = 1
        pinchAnchor = app.pinchTarget(at: point, in: app.level, visibleIn: contentFrame)
        let focus = pinchAnchor.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? point
        zoomAnchor = UnitPoint(
            x: (focus.x - contentFrame.minX) / max(contentFrame.width, 1),
            y: (focus.y - contentFrame.minY) / max(contentFrame.height, 1))
    }

    /// Spread = more detail (연간 → 월간 → 기록한 날 → 일간), pinch = less, one level per gesture.
    /// The anchored date keeps its place on screen in the next view.
    private func finishPinch(_ scale: CGFloat) {
        app.isPinching = false
        guard pinchActive else { return }
        pinchActive = false
        let from = app.level
        let to = InteractionRules.pinchLevel(from: from, scale: scale)
        guard to != from else {
            // Neutral release, cancel or first/last level: back to where it was, no tick.
            withAnimation(.easeOut(duration: InteractionRules.cancelDuration)) { pinchScale = 1 }
            pinchAnchor = nil
            return
        }

        var day = app.selectedDay
        switch pinchAnchor?.target {
        case .day(let anchored):
            day = anchored
        case .month(let month):
            day = month == app.selectedDay.monthKey ? app.selectedDay
                : store.days(in: month).first ?? (month == DayKey.today.monthKey ? .today : month.firstDay)
        case nil:
            break
        }
        let anchorY = pinchAnchor.map { ($0.frame.midY - contentFrame.minY) / max(contentFrame.height, 1) }
        pinchAnchor = nil
        app.searchHighlight = nil

        if reduceMotion {
            withAnimation(.easeOut(duration: InteractionRules.reduceMotionDuration)) {
                pinchScale = 1
                app.navigate(to: day, level: to)
            }
            app.requestReveal(day, anchorY: anchorY)
            return
        }

        // Grow the old view on through the release scale while the new one settles to 100%
        // from the matching size, both around the anchored date.
        let zoomingIn = to.rawValue > from.rawValue
        layerScale[to] = zoomingIn ? 1 / max(scale, 1) : 1 / min(scale, 1)
        layerScale[from] = scale
        pinchScale = 1
        app.requestReveal(day, anchorY: anchorY)
        withAnimation(.easeOut(duration: InteractionRules.commitDuration)) {
            app.navigate(to: day, level: to)
            layerScale[to] = 1
            layerScale[from] = zoomingIn ? scale * 1.2 : scale * 0.8
        } completion: {
            layerScale[from] = 1
        }
    }

    // MARK: Actions

    /// + opens the day on screen in 일간 (today elsewhere). That day's own draft is resumed;
    /// drafts kept on other days stay where they are.
    private func openAdd() {
        app.openEditor(for: app.level == .day ? app.selectedDay : .today)
    }

    private func deleteDay(_ day: DayKey) {
        do {
            let items = try store.deleteDay(day)
            showUndo(PendingUndo(message: String(localized: "이날 기록 \(items.count)개를 삭제했어요.")) {
                do { try store.restoreDay(day, items: items) } catch { showError(error) }
            })
        } catch {
            showError(error)
        }
    }

    private func showUndo(_ undo: PendingUndo) {
        pendingUndo = undo
        let id = undo.id
        Task {
            try? await Task.sleep(for: .seconds(8))
            if pendingUndo?.id == id { pendingUndo = nil }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = String(localized: "저장 공간을 확인한 뒤 다시 시도해 주세요.")
    }
}

/// "아직 남긴 기록이 없어요." with a shortcut to the first entry.
struct EmptyHome: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("아직 남긴 기록이 없어요.")
                .font(.brand(19, .medium))
                .foregroundStyle(Palette.primary)
            OutlineCapsuleButton(title: "첫 기록 남기기", systemImage: "plus") {
                app.openEditor(for: .today)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }
}

/// The mascot peeking from the bottom-right corner.
struct EmptyHomeRabbit: View {
    /// The artwork is drawn to peek up from the bottom edge of its square, so it sits flush
    /// with the screen bottom. Size follows the screen so every device shows ears, head and eyes.
    var body: some View {
        GeometryReader { geometry in
            let size = min(max(geometry.size.width * 0.52, 170), 300)
            Image("PeekRabbit")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.rabbit)
                .frame(width: size, height: size)
                .offset(x: size * 0.06)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
