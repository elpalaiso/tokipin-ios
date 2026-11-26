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
            if field.isFirstResponder { field.reloadInputViews() }
        }
        if isFocused && !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused && field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ComposerField

        init(parent: ComposerField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        /// With the emoji tool, only emoji get in, even if the person switches to another keyboard.
        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard parent.preferEmoji, !string.isEmpty else { return true }
            let emoji = String(string.filter { ItemValidator.containsEmoji(String($0)) })
            if emoji == string { return true }
            if !emoji.isEmpty, let current = field.text, let swiftRange = Range(range, in: current) {
                field.text = current.replacingCharacters(in: swiftRange, with: emoji)
                parent.text = field.text ?? ""
            }
            return false
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            // Finish any Hangul composition before reading the value.
            field.unmarkText()
            parent.text = field.text ?? ""
            parent.onReturn()
            return false
        }
    }

    final class InputField: UITextField {
        var preferEmoji = false

        override var textInputMode: UITextInputMode? {
            if preferEmoji, let emoji = UITextInputMode.activeInputModes.first(where: { $0.primaryLanguage == "emoji" }) {
                return emoji
            }
            return super.textInputMode
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
        }
    }
}
