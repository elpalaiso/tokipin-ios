import Accessibility
import SwiftUI

extension View {
    /// Keep the editor (or returning user's normal destination) visible behind the sheet.
    func usageSharingInvitation(isPresented: Binding<Bool>, onJoin: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) -> some View {
        modifier(UsageSharingInvitation(isPresented: isPresented, onJoin: onJoin, onDismiss: onDismiss))
    }
}

private struct UsageSharingInvitation: ViewModifier {
    @Binding var isPresented: Bool
    let onJoin: () -> Void
    let onDismiss: () -> Void
    @State private var explicitlySkipped = false
    @State private var showsReminder = false

    func body(content: Content) -> some View {
        content.accessibilityHidden(isPresented)
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsReminder {
                    let message = String(localized: "설정에서 ‘앱 사용 통계 공유’를 언제든 켤 수 있어요.")
                    Text(verbatim: message)
                        .font(.brand(14)).foregroundStyle(Palette.primary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .glassCard(cornerRadius: 16, fill: Palette.surface)
                        .padding(.horizontal, 16).padding(.vertical, 4)
                        .allowsHitTesting(false)
                        .task {
                            var announcement = AttributedString(message)
                            announcement.accessibilitySpeechAnnouncementPriority = .low
                            AccessibilityNotification.Announcement(announcement).post()
                            try? await Task.sleep(for: .seconds(5))
                            if !Task.isCancelled { showsReminder = false }
                        }
                }
            }
            .overlay {
                if isPresented {
                    Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { isPresented = false }
                        .accessibilityHidden(true)
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: {
                onDismiss()
                showsReminder = explicitlySkipped
                explicitlySkipped = false
            }) {
                UsageSharingSheet(onSkip: { explicitlySkipped = true }, onJoin: onJoin)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(LinearGradient(colors: [Color(hex: 0x343F39), Color(hex: 0x28332E)],
                                                           startPoint: .top, endPoint: .bottom))
                    .presentationCornerRadius(26)
            }
    }
}

private struct UsageSharingSheet: View {
    let onSkip: () -> Void
    let onJoin: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var measuredSize = CGSize(width: 390, height: 244)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("더 나은 토키핀을 함께 만들까요?")
                    .font(.brand(23, .medium, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text("앱 실행과 저장 횟수 같은 사용 통계를 참고해 불편한 점을 살피고 기능을 개선해요. 작성한 기록 내용과 검색어는 보내지 않아요.")
                    .font(.brand(15)).foregroundStyle(Palette.secondary)
                if typeSize.isAccessibilitySize || measuredSize.width < 350 {
                    VStack(spacing: 8) { actions }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { actions }
                        VStack(spacing: 8) { actions }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 22)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { measuredSize = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Palette.primary)
        .presentationDetents([.height(measuredSize.height)])
        .accessibilityAction(.escape) { dismiss() }
    }

    @ViewBuilder private var actions: some View {
        choice("지금은 안 함") {
            onSkip()
            dismiss()
        }
        choice("함께하기") {
            onJoin()
            dismiss()
        }
        .accessibilityHint(Text("앱 사용 통계 공유"))
    }

    private func choice(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.brand(16, .medium)).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(hex: 0x414E46), in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: 0x69766E)) }
        }
        .buttonStyle(.plain)
    }
}
