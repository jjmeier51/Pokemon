import SwiftUI

/// A holographic sheen driven by the card's tilt, in the spirit of the foil effects in the official apps.
struct HoloOverlay: View {
    var tilt: CGSize      // -1...1 on each axis
    var intensity: Double = 0.55
    var rarity: Rarity

    private var colors: [Color] {
        switch rarity {
        case .specialIllustrationRare, .illustrationRare:
            return [.clear, Color(hex: 0xFFE27A).opacity(0.9), Color(hex: 0x7CFF8B).opacity(0.6), Color(hex: 0x62D2FF).opacity(0.8), Color(hex: 0xFF8AE2).opacity(0.7), .clear]
        case .futuristicRare:
            return [.clear, Color(hex: 0x2FE3C6).opacity(0.9), .white.opacity(0.7), Color(hex: 0x4FA3FF).opacity(0.9), .clear]
        case .rgbSecret:
            return [.clear, Color(hex: 0xFF3B3B).opacity(0.8), Color(hex: 0x2ED573).opacity(0.8), Color(hex: 0x3B82F6).opacity(0.8), .clear]
        case .pikachuRare:
            return [.clear, PokeTheme.yellow.opacity(0.8), .white.opacity(0.6), Color(hex: 0xFF8A3D).opacity(0.6), .clear]
        default:
            return [.clear, .white.opacity(0.75), .clear]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let magnitude = min(1, sqrt(tilt.width * tilt.width + tilt.height * tilt.height))
            LinearGradient(colors: colors,
                           startPoint: UnitPoint(x: 0.5 + tilt.width * 0.9 - 0.6, y: 0.5 + tilt.height * 0.9 - 0.6),
                           endPoint: UnitPoint(x: 0.5 + tilt.width * 0.9 + 0.6, y: 0.5 + tilt.height * 0.9 + 0.6))
                .blendMode(.overlay)
                .opacity(intensity * (0.25 + 0.75 * magnitude))
                .frame(width: w, height: h)
                .allowsHitTesting(false)
        }
    }
}

/// Applies an interactive 3D tilt + holo sheen to any card artwork.
struct TiltCardModifier: ViewModifier {
    let rarity: Rarity
    let enabled: Bool
    @State private var tilt: CGSize = .zero
    @State private var dragging = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled {
                    HoloOverlay(tilt: tilt, rarity: rarity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .rotation3DEffect(.degrees(Double(tilt.height) * -12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(tilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(dragging ? 1.03 : 1)
            .shadow(color: .black.opacity(dragging ? 0.55 : 0.4), radius: dragging ? 30 : 18, x: -tilt.width * 12, y: 14 - tilt.height * 8)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        let x = max(-1, min(1, value.translation.width / 110))
                        let y = max(-1, min(1, value.translation.height / 110))
                        withAnimation(.interactiveSpring()) {
                            dragging = true
                            tilt = CGSize(width: x, height: y)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(duration: 0.7, bounce: 0.35)) {
                            tilt = .zero
                            dragging = false
                        }
                    }
            )
    }
}

extension View {
    func tiltCard(rarity: Rarity, enabled: Bool = true) -> some View {
        modifier(TiltCardModifier(rarity: rarity, enabled: enabled))
    }
}
