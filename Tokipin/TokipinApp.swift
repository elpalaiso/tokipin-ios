import SwiftUI

@main
struct TokipinApp: App {
    @State private var store = RecordStore()
    @State private var app = AppModel()

    init() {
        BrandFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(app)
                .preferredColorScheme(.dark)
                .tint(Palette.focus)
        }
    }
}
