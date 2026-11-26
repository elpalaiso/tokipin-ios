import MessageUI
import SwiftUI
import UIKit

/// The one place the support address lives: `TokipinSupportContact` in Info.plist
/// ({{support_contact}} in the design). Both the mail recipient and the copied address use it.
enum SupportContact {
    static var address: String {
        (Bundle.main.object(forInfoDictionaryKey: "TokipinSupportContact") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

/// Tokipin에 한마디 (Figma 267-1266): opens a mail draft to the support address, or copies
/// the address. Nothing is attached; sending stays the person's choice.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    /// Mail could not be opened (or copying failed): show the address to select by hand.
    @State private var showAddress = false
    @State private var composing = false

    private let address = SupportContact.address

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .regular))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("설정으로")
                Text("Tokipin에 한마디")
                    .font(.brand(20, .medium))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 62)

            VStack(alignment: .leading, spacing: 0) {
                Text("쓰면서 떠오른 생각이 있나요?\n어떤 이야기든 반가워요.")
                    .font(.brand(19, .medium))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)

                Button(action: sendMail) {
                    Label("메일로 보내기", systemImage: "envelope")
                        .font(.brand(16, .medium))
                        .foregroundStyle(Color(hex: 0x263028))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color(hex: 0xD5E0CC), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 40)

                Button(action: copyAddress) {
                    Label(copied ? "주소를 복사했어요" : "주소 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.brand(15))
                        .foregroundStyle(Palette.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .accessibilityLabel(copied ? Text("주소를 복사했어요") : Text("주소 복사"))

                if showAddress {
                    VStack(spacing: 12) {
                        Text("메일 앱을 열 수 없어요. 아래 주소로 보내주세요.")
                            .font(.brand(13))
                            .foregroundStyle(Palette.secondary)
                        Text(verbatim: address)
                            .font(.brand(16, .medium))
                            .textSelection(.enabled)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .transition(.opacity)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .foregroundStyle(Palette.primary)
        .background(Color(hex: 0x2E3832).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $composing) {
            MailComposer(recipient: address) { composing = false }
                .ignoresSafeArea()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: copied)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showAddress)
    }

    /// The system mail composer when Mail is set up, otherwise the default mail app via mailto.
    private func sendMail() {
        guard !address.isEmpty else { showAddress = true; return }
        if MFMailComposeViewController.canSendMail() {
            composing = true
        } else if let url = URL(string: "mailto:\(address)") {
            openURL(url) { accepted in if !accepted { showAddress = true } }
        } else {
            showAddress = true
        }
    }

    private func copyAddress() {
        guard !address.isEmpty else { showAddress = true; return }
        // Reading the pasteboard back would ask the person for paste permission;
        // the change count tells whether the write went through.
        let before = UIPasteboard.general.changeCount
        UIPasteboard.general.string = address
        guard UIPasteboard.general.changeCount != before else { showAddress = true; return }
        copied = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "주소를 복사했어요"))
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

/// System mail composer with the support address filled in; nothing attached.
private struct MailComposer: UIViewControllerRepresentable {
    let recipient: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([recipient])
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish()
        }
    }
}
