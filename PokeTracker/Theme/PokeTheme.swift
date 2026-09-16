import SwiftUI
import UIKit

/// Colors, gradients and type styles that echo the official Pokémon TCG apps.
enum PokeTheme {
    // Brand palette
    static let yellow = Color(hex: 0xFFCB05)
    static let gold = Color(hex: 0xF5B700)
    static let blue = Color(hex: 0x3B6FD8)
    static let brightBlue = Color(hex: 0x4FA3FF)
    static let red = Color(hex: 0xEE1515)
    static let navy = Color(hex: 0x0B1633)
    static let deepNavy = Color(hex: 0x060C1F)
    static let panel = Color(hex: 0x141F45)
    static let panelLight = Color(hex: 0x1D2B5C)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.5)

    /// Full-screen themed backdrop. Built from overlays on a size-less gradient so the
    /// decorative watermark can never widen the layout beyond the screen.
    static var background: some View {
        LinearGradient(colors: [Color(hex: 0x101E4B), navy, deepNavy], startPoint: .top, endPoint: .bottom)
            .overlay(RadialGradient(colors: [blue.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 520))
            .overlay(RadialGradient(colors: [red.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460))
            .overlay(alignment: .topTrailing) {
                PokeballWatermark()
                    .foregroundStyle(Color.white.opacity(0.035))
                    .frame(width: 420, height: 420)
                    .offset(x: 150, y: -120)
            }
            .clipped()
            .ignoresSafeArea()
    }

    static var panelGradient: LinearGradient {
        LinearGradient(colors: [panelLight, panel], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFE27A), gold, Color(hex: 0xD99A00)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var rainbowGradient: AngularGradient {
        AngularGradient(colors: [Color(hex: 0xFF5F6D), Color(hex: 0xFFC371), Color(hex: 0x7CFF8B), Color(hex: 0x62D2FF), Color(hex: 0xC77DFF), Color(hex: 0xFF5F6D)], center: .center)
    }

    static var rgbGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFF3B3B), Color(hex: 0x2ED573), Color(hex: 0x3B82F6)], startPoint: .leading, endPoint: .trailing)
    }

    // Typography — rounded, heavy headings feel closest to the TCG apps.
    static func display(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func headline(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .bold, design: .monospaced) }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: return Color(hex: 0xC9D1E3)
        case .rare: return Color(hex: 0xE8EEFF)
        case .doubleRare: return Color(hex: 0xFFD166)
        case .pikachuRare: return PokeTheme.yellow
        case .illustrationRare: return Color(hex: 0xFFB020)
        case .specialIllustrationRare: return Color(hex: 0xFF8A3D)
        case .futuristicRare: return Color(hex: 0x2FE3C6)
        case .rgbSecret: return Color(hex: 0xFF5C8A)
        case .classicCollection: return Color(hex: 0xE4C56B)
        case .promo: return Color(hex: 0x9FB8FF)
        }
    }

    var badgeBackground: AnyShapeStyle {
        switch self {
        case .specialIllustrationRare:
            return AnyShapeStyle(PokeTheme.rainbowGradient.opacity(0.9))
        case .rgbSecret:
            return AnyShapeStyle(PokeTheme.rgbGradient)
        case .futuristicRare:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x2FE3C6), Color(hex: 0x4FA3FF)], startPoint: .leading, endPoint: .trailing))
        case .illustrationRare, .doubleRare, .classicCollection:
            return AnyShapeStyle(PokeTheme.goldGradient)
        case .pikachuRare:
            return AnyShapeStyle(LinearGradient(colors: [PokeTheme.yellow, Color(hex: 0xFFA000)], startPoint: .leading, endPoint: .trailing))
        default:
            return AnyShapeStyle(color.opacity(0.9))
        }
    }

    var badgeForeground: Color {
        switch self {
        case .common, .rare: return PokeTheme.navy
        case .futuristicRare, .rgbSecret, .specialIllustrationRare: return .white
        default: return PokeTheme.navy
        }
    }
}

extension EnergyType {
    var color: Color {
        switch self {
        case .grass: return Color(hex: 0x4CB050)
        case .fire: return Color(hex: 0xF44336)
        case .water: return Color(hex: 0x2196F3)
        case .lightning: return Color(hex: 0xFFC107)
        case .psychic: return Color(hex: 0xA35BD6)
        case .fighting: return Color(hex: 0xC0692B)
        case .darkness: return Color(hex: 0x3A4A5C)
        case .metal: return Color(hex: 0x9EA7B3)
        case .dragon: return Color(hex: 0xC5A028)
        case .colorless: return Color(hex: 0xD9D9D9)
        case .fairy: return Color(hex: 0xF06292)
        }
    }

    var symbol: String {
        switch self {
        case .grass: return "leaf.fill"
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .lightning: return "bolt.fill"
        case .psychic: return "eye.fill"
        case .fighting: return "hand.raised.fill"
        case .darkness: return "moon.fill"
        case .metal: return "gearshape.fill"
        case .dragon: return "tornado"
        case .colorless: return "star.fill"
        case .fairy: return "sparkle"
        }
    }
}

/// A simple Poké Ball silhouette used as a background watermark.
struct PokeballWatermark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * 0.045
            ZStack {
                Circle().strokeBorder(lineWidth: lineWidth)
                Rectangle().frame(height: lineWidth)
                Circle().strokeBorder(lineWidth: lineWidth).frame(width: size * 0.3, height: size * 0.3)
                Circle().fill().frame(width: size * 0.14, height: size * 0.14)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Haptics

enum Haptics {
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium, enabled: Bool = true) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    @MainActor
    static func success(enabled: Bool = true) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    static func selection(enabled: Bool = true) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Reusable modifiers

struct PanelStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(PokeTheme.panelGradient, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func panel(cornerRadius: CGFloat = 20) -> some View { modifier(PanelStyle(cornerRadius: cornerRadius)) }
}
