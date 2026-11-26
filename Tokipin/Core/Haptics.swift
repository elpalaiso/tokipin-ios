import UIKit

/// One tick when a day or view level actually changes. Respects the settings toggle.
enum Haptics {
    static let enabledKey = "tokipin.hapticsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    @MainActor
    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
