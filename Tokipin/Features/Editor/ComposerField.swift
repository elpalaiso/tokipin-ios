import SwiftUI
import UIKit

/// Text field for the composer. Return confirms one item and keeps the keyboard up;
/// for emoji it asks iOS for the emoji keyboard.
struct ComposerField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont
    var preferEmoji: Bool
    var isFocused: Bool
    var accessibilityLabel: String
    var onReturn: () -> Void

    func makeUIView(context: Context) -> InputField {
        let field = InputField()
        field.delegate = context.coordinator
        field.textColor = UIColor(Palette.primary)
        field.tintColor = UIColor(Palette.focus)
        field.returnKeyType = .default
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.adjustsFontForContentSizeCategory = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: InputField, context: Context) {
        context.coordinator.parent = self
        if field.text != text && field.markedTextRange == nil { field.text = text }
        field.font = font
        field.accessibilityLabel = accessibilityLabel
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: UIColor(Palette.secondary.opacity(0.5)), .font: font
        ])
        if field.preferEmoji != preferEmoji {
            field.preferEmoji = preferEmoji
            // iOS reads textInputMode when a field becomes first responder, so switch
            // keyboards by handing focus back and forth (reloadInputViews alone keeps the old one).
            if field.isFirstResponder {
                field.resignFirstResponder()
                field.becomeFirstResponder()
            }
        }
        if isFocused && !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused && field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Edits pass through untouched outside the emoji tool and during IME composition.
    static func shouldPassThroughEdit(preferEmoji: Bool, isComposing: Bool) -> Bool {
        !preferEmoji || isComposing
    }

    /// Return confirms an item unless the emoji field is mid-composition.
    static func shouldCommitOnReturn(preferEmoji: Bool, isComposing: Bool) -> Bool {
        !(preferEmoji && isComposing)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ComposerField

        init(parent: ComposerField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            // After an IME composition ends, drop anything that is not emoji (UX v0.1 §4).
            if parent.preferEmoji, field.markedTextRange == nil, let text = field.text {
                let cleaned = EmojiRules.filter(text)
                if cleaned != text { field.text = cleaned }
            }
            parent.text = field.text ?? ""
        }

        /// With the emoji tool only emoji get in, from any keyboard or paste. Invalid-only
        /// input leaves the text and selection untouched; composition is never rewritten.
        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !ComposerField.shouldPassThroughEdit(preferEmoji: parent.preferEmoji, isComposing: field.markedTextRange != nil),
                  !string.isEmpty else { return true }
            let emoji = EmojiRules.filter(string)
            if emoji == string { return true }
            guard !emoji.isEmpty,
                  let start = field.position(from: field.beginningOfDocument, offset: range.location),
                  let end = field.position(from: start, offset: range.length),
                  let textRange = field.textRange(from: start, to: end) else { return false }
            field.replace(textRange, withText: emoji)
            return false
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            guard ComposerField.shouldCommitOnReturn(preferEmoji: parent.preferEmoji,
                                                     isComposing: field.markedTextRange != nil) else {
                // Still composing (e.g. Hangul) in the emoji field: let the IME finish, add nothing.
                return false
            }
            // Finish any Hangul composition before reading the value.
            field.unmarkText()
            parent.text = field.text ?? ""
            parent.onReturn()
            return false
        }
    }

    final class InputField: UITextField {
        var preferEmoji = false
        /// The letter keyboard the person used last (e.g. Korean), restored after the emoji tool.
        static var lastTextLanguage: String?

        override var textInputMode: UITextInputMode? {
            let modes = UITextInputMode.activeInputModes
            let current = super.textInputMode
            if preferEmoji {
                // Ask for the enabled system emoji keyboard; without one, keep the current keyboard.
                if let index = EmojiKeyboard.preferredIndex(languages: modes.map(\.primaryLanguage)) {
                    return modes[index]
                }
                return current
            }
            // Word and place: a letter keyboard, never the emoji one left over from the emoji tool.
            if let current, current.primaryLanguage != "emoji" {
                Self.lastTextLanguage = current.primaryLanguage
                return current
            }
            if let index = EmojiKeyboard.textIndex(languages: modes.map(\.primaryLanguage), lastUsed: Self.lastTextLanguage) {
                return modes[index]
            }
            return current
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
        }
    }
}

/// Which active keyboard the emoji tool asks for. The app never shows its own palette.
enum EmojiKeyboard {
    static let appSuggestedPalette = false

    static func preferredIndex(languages: [String?]) -> Int? {
        languages.firstIndex { $0 == "emoji" }
    }

    /// Letter keyboard for word/place: the one used last if still active, else the first non-emoji one.
    static func textIndex(languages: [String?], lastUsed: String?) -> Int? {
        if let lastUsed, let index = languages.firstIndex(where: { $0 == lastUsed }) { return index }
        return languages.firstIndex { $0 != nil && $0 != "emoji" }
    }
}
