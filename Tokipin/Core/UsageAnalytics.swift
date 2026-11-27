import Foundation
import Observation
import FirebaseCore
import FirebaseAnalytics

/// These are the only two operations the journal can perform on the analytics SDK.
/// The save event deliberately accepts no values from an entry.
@MainActor
struct UsageAnalyticsClient {
    let available: Bool
    let setEnabled: (Bool) -> Void
    let recordSave: () -> Void

    static var firebase: Self {
        Self(available: Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil,
             setEnabled: { enabled in
                 if FirebaseApp.app() == nil {
                     guard enabled else { return }
                     FirebaseApp.configure()
                 }
                 if !enabled { Analytics.setAnalyticsCollectionEnabled(false) }
                 Analytics.setConsent([
                     .analyticsStorage: enabled ? .granted : .denied,
                     .adStorage: .denied, .adUserData: .denied, .adPersonalization: .denied
                 ])
                 if enabled { Analytics.setAnalyticsCollectionEnabled(true) }
             },
             recordSave: { Analytics.logEvent("record_saved", parameters: nil) })
    }
}

@MainActor
@Observable
final class UsageAnalytics {
    private enum Choice: String { case off, on }
    private let directory: URL
    private let client: UsageAnalyticsClient
    private var choice: Choice?

    var isAvailable: Bool { client.available }
    var isEnabled: Bool { client.available && choice == .on }

    init(directory: URL, client: UsageAnalyticsClient) {
        self.directory = directory
        self.client = client
        if let value = try? String(contentsOf: directory.appendingPathComponent("choice"), encoding: .utf8) {
            choice = Choice(rawValue: value)
        }
        if isEnabled { client.setEnabled(true) }
    }

    convenience init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: support.appendingPathComponent("TokipinUsageSharing", isDirectory: true), client: .firebase)
    }

    /// Mark the offer seen before presenting it. An interrupted first launch stays off.
    func claimInvitation() -> Bool {
        guard isAvailable, choice == nil else { return false }
        return persist(.off)
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable, isEnabled != enabled else { return }
        if enabled {
            if persist(.on) { client.setEnabled(true) }
        } else {
            client.setEnabled(false)
            if !persist(.off) {
                // Fail closed even if replacing the file fails (e.g. disk full).
                choice = .off
                try? FileManager.default.removeItem(at: directory.appendingPathComponent("choice"))
            }
        }
    }

    func didSaveRecord() {
        if isEnabled { client.recordSave() }
    }

    private func persist(_ newChoice: Choice) -> Bool {
        do {
            var folder = directory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // A restored journal must not silently opt a different installation into analytics.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try Data(newChoice.rawValue.utf8).write(to: folder.appendingPathComponent("choice"), options: .atomic)
            choice = newChoice
            return true
        } catch {
            return false
        }
    }
}
