import SwiftUI
import UIKit
import CoreText

/// 세이지 차콜 palette from the Figma "Tone & manner" page.
enum Palette {
    static let canvas = Color(hex: 0x39453D)
    static let surface = Color(hex: 0x252C29)
    static let primary = Color(hex: 0xF3F3EC)
    static let secondary = Color(hex: 0xC3CDC5)
    static let focus = Color(hex: 0xBBD2F2)
    static let onFocus = Color(hex: 0x263746)
    static let muted = Color(hex: 0xC3CDC5).opacity(0.62)
    static let line = Color.white.opacity(0.09)
    static let danger = Color(hex: 0x8A4B45)
    /// Mascot green used for the peek rabbit on the empty home.
    static let rabbit = Color(hex: 0x9DB18F)

    // Background gradient: slate at the top, warm charcoal at the bottom. (Sampled from Figma screens.)
    static let backgroundTop = Color(hex: 0x3D4A50)
    static let backgroundMid = Color(hex: 0x333D37)
    static let backgroundBottom = Color(hex: 0x473F3B)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// DM Sans for Latin and numbers, falling back to Noto Sans KR for Hangul.
enum BrandFont {
    private static let wghtAxis = 0x77676874 // 'wght'
    private static let opszAxis = 0x6F70737A // 'opsz'

    static func register() {
        for name in ["DMSans", "NotoSansKR"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: UIFont.TextStyle = .body) -> UIFont {
        let w = numericWeight(weight)
        let noto = UIFontDescriptor(fontAttributes: [
            .name: "NotoSansKR-Thin",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: w]
        ])
        let dm = UIFontDescriptor(fontAttributes: [
            .name: "DMSans-9ptRegular",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: w, opszAxis: min(max(size, 9), 40)],
            .cascadeList: [noto]
        ])
        let font = UIFont(descriptor: dm, size: size)
        // Fall back to the system font if the bundled fonts are missing.
        let base = font.familyName == "DM Sans" ? font : UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    private static func numericWeight(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        default: 400
        }
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        default: .regular
        }
    }
}

extension Font {
    static func brand(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: UIFont.TextStyle = .body) -> Font {
        Font(BrandFont.uiFont(size, weight, relativeTo: style))
    }
}

/// Full-screen backdrop shared by every screen.
struct BrandBackground: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Palette.backgroundTop, location: 0),
            .init(color: Palette.backgroundMid, location: 0.45),
            .init(color: Palette.backgroundBottom, location: 1)
        ], startPoint: .topTrailing, endPoint: .bottomLeading)
        .ignoresSafeArea()
    }
}

/// "유리에는 얇은 빛을": calm surface cards with a thin light edge.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    var fill: Color = Palette.surface.opacity(0.82)

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18, fill: Color = Palette.surface.opacity(0.82)) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, fill: fill))
    }
}
