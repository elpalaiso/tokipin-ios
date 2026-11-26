import SwiftUI

/// Round 44pt control with a thin outline (back, check, more).
struct CircleIconButton<Label: View>: View {
    let accessibilityLabel: LocalizedStringKey
    var highlighted = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 22, height: 22)
                .foregroundStyle(highlighted ? Palette.onFocus : Palette.primary)
                .frame(width: 44, height: 44)
                .background(highlighted ? Palette.focus : Color.white.opacity(0.04), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(highlighted ? 0 : 0.22), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Plain 44pt icon used in the explore header (search, view menu).
struct HeaderIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(Palette.primary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

struct KindIcon: View {
    let kind: ItemKind
    var size: CGFloat = 18
    var color: Color = Palette.secondary

    var body: some View {
        Image(kind.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// Bottom toast with an undo action ("항목을 삭제했어요. 실행 취소").
struct UndoToast: View {
    let message: String
    var actionTitle: LocalizedStringKey = "실행 취소"
    let action: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.brand(14))
                .foregroundStyle(Palette.primary)
            Spacer(minLength: 12)
            Button(actionTitle, action: action)
                .font(.brand(14, .medium))
                .foregroundStyle(Palette.focus)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .glassCard(cornerRadius: 16, fill: Color(hex: 0x2F3A33).opacity(0.96))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Capsule "오늘" and round "+" at the bottom of explore screens.
struct FloatingCapsuleButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.brand(14, .medium))
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [Color(hex: 0x56635A), Color(hex: 0x3A463F)], startPoint: .top, endPoint: .bottom),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.primary)
                .frame(width: 54, height: 54)
                .background(
                    RadialGradient(colors: [Color(hex: 0x66746B), Color(hex: 0x36423B)], center: .topLeading, startRadius: 2, endRadius: 60),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("기록 추가")
    }
}

/// Outlined capsule used for secondary actions ("달력 보기", "다시 시도").
struct OutlineCapsuleButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 16, weight: .light)) }
                Text(title).font(.brand(15, .medium))
            }
            .foregroundStyle(Palette.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
