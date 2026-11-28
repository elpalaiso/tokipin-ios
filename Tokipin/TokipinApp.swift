import SwiftUI

@main
struct TokipinApp: App {
    @State private var store: RecordStore = {
        #if DEBUG
        TokipinApp.resetForUITestsIfAsked()
        #endif
        return RecordStore()
    }()
    @State private var app = AppModel()
    @State private var usage = UsageAnalytics()

    init() {
        BrandFont.register()
    }

    #if DEBUG
    /// UI tests (TokipinUITests) pass `-uiTestFreshInstall` to start like a new install: no records,
    /// drafts, first-run mark or usage choice.
    static func resetForUITestsIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestFreshInstall") else { return }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for folder in ["Tokipin", "TokipinUsageSharing"] {
            try? FileManager.default.removeItem(at: support.appendingPathComponent(folder, isDirectory: true))
        }
        for key in ["tokipin.hasOpenedEditor", "tokipin.completedSampleCalendar"] {
            // Set false rather than remove: a removed key could still be read from another domain.
            UserDefaults.standard.set(false, forKey: key)
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(app)
                .environment(usage)
                .preferredColorScheme(.dark)
                .tint(Palette.focus)
        }
    }
}
