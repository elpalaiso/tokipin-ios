import SwiftUI

@main
struct TokipinApp: App {
    @State private var store = RecordStore()
    @State private var app = AppModel()
    @State private var usage = UsageAnalytics()

    init() {
        BrandFont.register()
    }

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
