import SwiftUI

extension View {
    /// Keep the editor (or returning user's normal destination) visible behind the sheet.
    func usageSharingInvitation(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void = {}) -> some View {
        self.accessibilityHidden(isPresented.wrappedValue)
            .overlay {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { isPresented.wrappedValue = false }
                        .accessibilityHidden(true)
                }
            }
            .sheet(isPresented: isPresented, onDismiss: onDismiss) {
                UsageSharingSheet()
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(LinearGradient(colors: [Color(hex: 0x343F39), Color(hex: 0x28332E)],
                                                           startPoint: .top, endPoint: .bottom))
                    .presentationCornerRadius(26)
            }
    }
}

private struct UsageSharingSheet: View {
    @Environment(UsageAnalytics.self) private var usage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var height: CGFloat = 244

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("토키핀 개선에 함께할까요?")
                    .font(.brand(23, .medium, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text("기록 기능을 더 편하게 만드는 데 도움이 돼요. 공유하면 앱 실행과 저장 횟수를 Google Analytics로 보내요. 기록 내용과 검색어는 보내지 않아요.")
                    .font(.brand(15)).foregroundStyle(Palette.secondary)
                if typeSize.isAccessibilitySize {
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
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Palette.primary)
        .presentationDetents([.height(height)])
        .accessibilityAction(.escape) { dismiss() }
    }

    @ViewBuilder private var actions: some View {
        choice("지금은 안 함") { dismiss() }
        choice("공유하기") {
            usage.setEnabled(true)
            dismiss()
        }
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
