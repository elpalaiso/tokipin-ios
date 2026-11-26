import SwiftUI

/// Launch → (skeleton if slow) → first-run editor, explore, or the read-failure screen.
struct RootView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var showSkeleton = false
    @State private var didRoute = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        ZStack {
            BrandBackground()
            switch store.state {
            case .idle, .loading:
                if showSkeleton { LoadingSkeleton() }
            case .failed:
                RecoveryView { Task { await load() } }
            case .loaded:
                ExploreView()
            }
        }
        .fullScreenCover(item: $app.editorDay) { day in
            EditorView(day: day, focusItem: app.editorFocusItem, startsWithKeyboard: app.editorStartsWithKeyboard)
        }
        .task { await load() }
        // The month may roll over while the app is in the background or the time zone changes.
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshToday() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshToday() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshToday() }
    }

    private func refreshToday() {
        let now = DayKey.today
        if app.today != now { app.today = now }
    }

    private func load() async {
        showSkeleton = false
        let slow = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if !Task.isCancelled { showSkeleton = true }
        }
        await store.load()
        slow.cancel()
        guard store.state == .loaded, !didRoute else { return }
        didRoute = true
        if let draft = store.latestDraft {
            // The app was interrupted mid-entry: bring the draft back.
            app.select(draft.day, haptic: false)
            app.openEditor(for: draft.day)
        } else if store.isFirstLaunch && store.isEmpty {
            app.openEditor(for: .today)
        }
    }
}

/// Shown only when reading takes long. Hidden from VoiceOver except one announcement.
struct LoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Capsule().frame(width: 76, height: 34)
                Spacer()
                Circle().frame(width: 34, height: 34)
                Circle().frame(width: 34, height: 34)
            }
            Capsule().frame(width: 74, height: 12)
            RoundedRectangle(cornerRadius: 18).frame(height: 148)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18).frame(height: 130)
                RoundedRectangle(cornerRadius: 18).frame(height: 130)
            }
            Spacer()
        }
        .foregroundStyle(Color.white.opacity(0.07))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .accessibilityElement()
        .accessibilityLabel("기록을 불러오는 중이에요.")
    }
}

struct RecoveryView: View {
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("기록을 불러오지 못했어요")
                .font(.brand(22, .semibold))
            Text("기기에 저장된 기록을 읽을 수 없어요.\n잠시 후 다시 시도해 주세요.")
                .font(.brand(15))
                .foregroundStyle(Palette.secondary)
            OutlineCapsuleButton(title: "다시 시도", action: retry)
                .padding(.top, 8)
            Spacer()
        }
        .foregroundStyle(Palette.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }
}
