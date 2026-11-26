import UIKit

/// Native haptic adapter. When to tick is decided in InteractionRules.
enum Haptics {
    static let enabledKey = "tokipin.hapticsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Native light selection tick. Call only through `AppModel.navigate`, which applies
    /// the product rules (InteractionRules.ticks) and the settings toggle.
    @MainActor
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
