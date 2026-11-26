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
    /// Live pinch scale, used only for visual feedback while fingers are down.
    @State private var pinchScale: CGFloat = 1
    @State private var pinchAnchor: PinchTarget?

    var body: some View {
        @Bindable var app = app
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .scaleEffect(min(max(pinchScale, 0.9), 1.1))
                    .opacity(1 - min(abs(pinchScale - 1), 0.3))
            }
            .background(
                PinchCatcher(
                    isEnabled: app.editorDay == nil && !app.isSearching && !app.isShowingSettings,
                    onBegin: { pinchAnchor = app.pinchTarget(at: $0) },
                    onChange: { pinchScale = $0 },
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
        .animation(.easeOut(duration: 0.2), value: app.level)
        .animation(.easeOut(duration: 0.2), value: pendingUndo?.id)
        .animation(.easeOut(duration: 0.18), value: app.isSearching)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            if let parent = parentLevel {
                Button {
                    app.searchHighlight = nil
                    app.setLevel(parent)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .regular))
                        Text(headerTitle).font(.brand(22, .medium, relativeTo: .title2))
                    }
                    .foregroundStyle(Palette.primary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(parent == .month ? Text("\(headerTitle)월 달력으로") : Text("\(headerTitle)년으로"))
            }
            Spacer()
            if app.level == .day {
                Menu {
                    Button { app.openEditor(for: app.selectedDay) } label: { Label("이날 기록하기", systemImage: "pencil") }
                    if !store.items(on: app.selectedDay).isEmpty {
                        Button(role: .destructive) { dayToDelete = app.selectedDay } label: {
                            Label("이날 기록 삭제", systemImage: "trash")
                        }
                    }
                } label: { HeaderIcon(systemName: "ellipsis") }
                .accessibilityLabel("이날 더보기")
            }
            if app.searchHighlight != nil && app.level == .day {
                Button {
                    app.isSearching = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass").font(.system(size: 13))
                        Text("검색 결과").font(.brand(13))
                    }
                    .foregroundStyle(Palette.primary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            } else {
                Button { app.isSearching = true } label: { HeaderIcon(systemName: "magnifyingglass") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("기록 검색")
            }
            viewMenu
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 56)
    }

    private var viewMenu: some View {
        Menu {
            Picker("탐색 보기", selection: Binding(get: { app.level }, set: { app.searchHighlight = nil; app.setLevel($0) })) {
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
        case .day: .month
        case .records, .month: .year
        case .year: nil
        }
    }

    private var headerTitle: String {
        app.level == .day ? "\(app.selectedDay.month)" : "\(app.focusedMonth.year)"
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch app.level {
        case .day:
            DayView(onUndo: showUndo, onError: showError)
        case .records:
            if store.isEmpty {
                EmptyHome()
            } else {
                RecordsView(onLongPress: { dayToDelete = $0 })
            }
        case .month:
            MonthView()
        case .year:
            YearView()
        }
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
                    FloatingAddButton { openAdd() }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 6)
    }

    /// Spread = more detail (연간 → 월간 → 기록한 날 → 일간), pinch = less.
    /// The date or month between the fingers becomes the anchor; otherwise the selected day stays.
    /// Thresholds match Android (1.25× in, 0.8× out).
    private func finishPinch(_ scale: CGFloat) {
        defer {
            pinchAnchor = nil
            withAnimation(.easeOut(duration: 0.2)) { pinchScale = 1 }
        }
        let next: ExploreLevel?
        if scale >= 1.25 { next = app.level.zoomedIn }
        else if scale <= 0.8 { next = app.level.zoomedOut }
        else { next = nil }
        guard let next else { return }

        switch pinchAnchor {
        case .day(let day):
            app.select(day, haptic: false)
            app.focusedMonth = day.monthKey
        case .month(let month):
            let recorded = store.days(in: month)
            app.select(recorded.first ?? (month == DayKey.today.monthKey ? .today : month.firstDay), haptic: false)
            app.focusedMonth = month
        case nil:
            break
        }
        app.searchHighlight = nil
        app.setLevel(next)
    }

    // MARK: Actions

    private func openAdd() {
        if let draft = store.draft {
            app.openEditor(for: draft.day)
        } else {
            app.openEditor(for: app.level == .day ? app.selectedDay : .today)
        }
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
    var body: some View {
        Image("PeekRabbit")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Palette.rabbit)
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .offset(x: 30, y: 40)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
