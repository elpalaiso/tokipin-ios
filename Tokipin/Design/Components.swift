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
    var systemImage = "plus"
    var accessibilityLabel: LocalizedStringKey = "기록 추가"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: systemImage == "plus" ? 22 : 19, weight: .light))
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
        .accessibilityLabel(accessibilityLabel)
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

/// Shared empty state for an empty 일간 day and an empty 기록한 날 month (Figma 211:2990):
/// a 172×120 group — the peek rabbit (90×90) behind a 172×69 glass card that hides the lower face.
/// Width is 44% of the page (max 172), centred, with its centre at 30% of the height between the
/// date/month rail and the bottom buttons. Decoration only; VoiceOver reads `label` once.
struct EmptyRecordArt: View {
    let label: String

    static func size(forPageWidth width: CGFloat) -> CGSize {
        let w = min((width * 0.44).rounded(), 172)
        return CGSize(width: w, height: (w * 120 / 172).rounded())
    }

    /// Vertical centre at 30% of the free height, kept inside 8pt margins on short screens.
    static func centerY(forHeight height: CGFloat, artHeight: CGFloat) -> CGFloat {
        let margin: CGFloat = 8
        let low = artHeight / 2 + margin, high = height - artHeight / 2 - margin
        guard high > low else { return height / 2 }
        return min(max(height * 0.3, low), high)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = Self.size(forPageWidth: geometry.size.width)
            art(scale: size.width / 172)
                .frame(width: size.width, height: size.height)
                .position(x: geometry.size.width / 2,
                          y: Self.centerY(forHeight: geometry.size.height, artHeight: size.height))
        }
        .accessibilityElement()
        .accessibilityLabel(label)
    }

    private func art(scale s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Above the card: ears and eyes only.
            Image("PeekRabbit")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xD9E4C8), Palette.rabbit],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 90 * s, height: 90 * s)
                .offset(x: 72 * s, y: -28 * s)
                .frame(width: 172 * s, height: 52 * s, alignment: .topLeading)
                .clipped()
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x5A6B62, opacity: 0.85), Color(hex: 0x2E3934, opacity: 0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: 172 * s, height: 69 * s)
                .offset(y: 51 * s)
        }
        .frame(width: 172 * s, height: 120 * s, alignment: .topLeading)
    }
}

enum EmptyStateText {
    static var day: String { String(localized: "이날 남긴 기록이 없어요.") }

    /// "12월에 남긴 기록이 없어요." with the month named in the app's language.
    static func month(_ month: MonthKey) -> String {
        let formatter = DateFormatter()
        formatter.locale = TimeRules.displayLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        let name = formatter.string(from: month.firstDay.date)
        return String(localized: "\(name)에 남긴 기록이 없어요.")
    }
}
