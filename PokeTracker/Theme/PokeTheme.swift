import SwiftUI
import UIKit

/// A color scheme for one expansion.
struct AppTheme {
    enum ID: String, Codable { case celebration30, celebrations25 }

    let id: ID
    let accent: Color          // headline yellow
    let gold: Color
    let secondary: Color       // blue on the 30th theme, warm gold on Celebrations
    let secondaryBright: Color
    let red: Color
    let base: Color            // main background
    let baseDeep: Color        // darkest background / bars
    let baseTop: Color         // top of the background gradient
    let panel: Color
    let panelLight: Color
    let glowA: Color           // top-left radial glow
    let glowB: Color           // bottom-right radial glow

    static let celebration30 = AppTheme(
        id: .celebration30,
        accent: Color(hex: 0xFFCB05), gold: Color(hex: 0xF5B700),
        secondary: Color(hex: 0x3B6FD8), secondaryBright: Color(hex: 0x4FA3FF),
        red: Color(hex: 0xEE1515),
        base: Color(hex: 0x0B1633), baseDeep: Color(hex: 0x060C1F), baseTop: Color(hex: 0x101E4B),
        panel: Color(hex: 0x141F45), panelLight: Color(hex: 0x1D2B5C),
        glowA: Color(hex: 0x3B6FD8).opacity(0.35), glowB: Color(hex: 0xEE1515).opacity(0.18))

    /// Celebrations: black with the set's yellow and gold foil.
    static let celebrations25 = AppTheme(
        id: .celebrations25,
        accent: Color(hex: 0xFFD400), gold: Color(hex: 0xE6B422),
        secondary: Color(hex: 0xC99A1E), secondaryBright: Color(hex: 0xFFE066),
        red: Color(hex: 0xE3242B),
        base: Color(hex: 0x0A0A0A), baseDeep: Color(hex: 0x000000), baseTop: Color(hex: 0x1A1607),
        panel: Color(hex: 0x161616), panelLight: Color(hex: 0x232323),
        glowA: Color(hex: 0xFFD400).opacity(0.22), glowB: Color(hex: 0xFFD400).opacity(0.10))

    static func theme(for id: ID) -> AppTheme {
        switch id {
        case .celebration30: return .celebration30
        case .celebrations25: return .celebrations25
        }
    }
}

/// Colors, gradients and type styles that echo the official Pokémon TCG apps.
/// Backed by `current`, which switches with the selected set; the root view re-identifies
/// itself on a set change so every view re-reads these values.
enum PokeTheme {
    private(set) static var current: AppTheme = .celebration30

    static func apply(setID: String) {
        let id = CardSet.shipped[setID]?.theme ?? .celebration30
        current = AppTheme.theme(for: id)
    }

    // Brand palette
    static var yellow: Color { current.accent }
    static var gold: Color { current.gold }
    static var blue: Color { current.secondary }
    static var brightBlue: Color { current.secondaryBright }
    static var red: Color { current.red }
    static var navy: Color { current.base }
    static var deepNavy: Color { current.baseDeep }
    static var panel: Color { current.panel }
    static var panelLight: Color { current.panelLight }
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.5)

    /// Full-screen themed backdrop. Built from overlays on a size-less gradient so the
    /// decorative watermark can never widen the layout beyond the screen.
    static var background: some View {
        LinearGradient(colors: [current.baseTop, current.base, current.baseDeep], startPoint: .top, endPoint: .bottom)
            .overlay(RadialGradient(colors: [current.glowA, .clear], center: .topLeading, startRadius: 0, endRadius: 520))
            .overlay(RadialGradient(colors: [current.glowB, .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460))
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
        LinearGradient(colors: [current.panelLight, current.panel], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        case .holoRare: return Color(hex: 0xC7E3FF)
        case .holoRareV: return Color(hex: 0xB9F0FF)
        case .holoRareVMAX: return Color(hex: 0xFF9BD6)
        case .ultraRare: return Color(hex: 0xFFB020)
        case .secretRare: return Color(hex: 0xFFD700)
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
        case .illustrationRare, .doubleRare, .classicCollection, .ultraRare, .secretRare:
            return AnyShapeStyle(PokeTheme.goldGradient)
        case .holoRareVMAX:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF5F9E), Color(hex: 0xC77DFF)], startPoint: .leading, endPoint: .trailing))
        case .holoRare, .holoRareV:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE6F2FF), Color(hex: 0xA9D4FF)], startPoint: .leading, endPoint: .trailing))
        case .pikachuRare:
            return AnyShapeStyle(LinearGradient(colors: [PokeTheme.yellow, Color(hex: 0xFFA000)], startPoint: .leading, endPoint: .trailing))
        default:
            return AnyShapeStyle(color.opacity(0.9))
        }
    }

    var badgeForeground: Color {
        switch self {
        case .common, .rare, .holoRare, .holoRareV: return Color(hex: 0x0B1633)
        case .futuristicRare, .rgbSecret, .specialIllustrationRare, .holoRareVMAX: return .white
        default: return Color(hex: 0x0B1633)
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
