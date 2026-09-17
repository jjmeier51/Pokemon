import SwiftUI

/// How a rarity's border should sparkle.
struct GlitterStyle {
    var colors: [Color]
    var sparkleColors: [Color]
    var density: Double      // relative number of sparkles
    var intensity: Double    // 0...1 brightness of the sheen and sparkles
}

extension Rarity {
    /// Nil for cards that shouldn't sparkle (commons, promos).
    var glitter: GlitterStyle? {
        switch self {
        case .common, .promo:
            return nil
        case .rare:
            return GlitterStyle(colors: [Color(hex: 0xD9E2F5), .white, Color(hex: 0xB8C6E6)],
                                sparkleColors: [.white, Color(hex: 0xE8EEFF)], density: 0.45, intensity: 0.6)
        case .doubleRare:
            return GlitterStyle(colors: [Color(hex: 0xFFE27A), .white, Color(hex: 0xE3B341)],
                                sparkleColors: [.white, Color(hex: 0xFFF1B8)], density: 0.7, intensity: 0.8)
        case .pikachuRare:
            return GlitterStyle(colors: [PokeTheme.yellow, .white, Color(hex: 0xFF8A3D), PokeTheme.yellow],
                                sparkleColors: [.white, Color(hex: 0xFFF3A0), Color(hex: 0xFFD166)], density: 0.9, intensity: 0.9)
        case .illustrationRare:
            return GlitterStyle(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF5B700), .white, Color(hex: 0xD99A00)],
                                sparkleColors: [.white, Color(hex: 0xFFF1B8), Color(hex: 0xFFD166)], density: 1, intensity: 0.9)
        case .specialIllustrationRare:
            return GlitterStyle(colors: [Color(hex: 0xFF5F6D), Color(hex: 0xFFC371), Color(hex: 0x7CFF8B), Color(hex: 0x62D2FF), Color(hex: 0xC77DFF), Color(hex: 0xFF5F6D)],
                                sparkleColors: [.white, Color(hex: 0xFFE9F3), Color(hex: 0xC8F7FF), Color(hex: 0xFFF3A0)], density: 1.3, intensity: 1)
        case .futuristicRare:
            return GlitterStyle(colors: [Color(hex: 0x2FE3C6), .white, Color(hex: 0x4FA3FF), Color(hex: 0x2FE3C6)],
                                sparkleColors: [.white, Color(hex: 0xBDFFF4), Color(hex: 0xA8D8FF)], density: 1.3, intensity: 1)
        case .rgbSecret:
            return GlitterStyle(colors: [Color(hex: 0xFF3B3B), Color(hex: 0x2ED573), Color(hex: 0x3B82F6), Color(hex: 0xFF3B3B)],
                                sparkleColors: [.white, Color(hex: 0xFFB3B3), Color(hex: 0xB3FFCF), Color(hex: 0xB3D1FF)], density: 1.4, intensity: 1)
        case .classicCollection:
            return GlitterStyle(colors: [Color(hex: 0xFFE9A0), Color(hex: 0xE3B341), .white, Color(hex: 0xC48F0A), Color(hex: 0xFFE9A0)],
                                sparkleColors: [.white, Color(hex: 0xFFF1B8), Color(hex: 0xFFE27A)], density: 1.2, intensity: 1)
        }
    }
}

/// An animated foil border: a sheen that sweeps around the card edge plus twinkling sparkles.
/// Drawn with Canvas inside a TimelineView so it stays cheap even with many cards on screen.
struct GlitterBorder: View {
    let style: GlitterStyle
    var cornerRadius: CGFloat = 10
    var lineWidth: CGFloat = 2.5
    var baseSparkles: Int = 40
    var opacity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                render(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    render(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private func render(time: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let radius = max(0, cornerRadius - lineWidth / 2)
            let border = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)

            // 1. Base metallic border.
            ctx.stroke(border,
                       with: .linearGradient(Gradient(colors: style.colors), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // 2. Sweeping specular sheen.
            let phase = (time * 0.28).truncatingRemainder(dividingBy: 1)          // 0...1 over ~3.5s
            let travel = size.width + size.height
            let offset = CGFloat(phase) * travel * 1.6 - travel * 0.3
            let start = CGPoint(x: offset - size.height * 0.35, y: 0)
            let end = CGPoint(x: offset + size.height * 0.35, y: size.height)
            let sheen = Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.15 * style.intensity), location: 0.35),
                .init(color: .white.opacity(0.95 * style.intensity), location: 0.5),
                .init(color: .white.opacity(0.15 * style.intensity), location: 0.65),
                .init(color: .clear, location: 1)
            ])
            var sheenCtx = ctx
            sheenCtx.blendMode = .plusLighter
            sheenCtx.stroke(border, with: .linearGradient(sheen, startPoint: start, endPoint: end),
                            style: StrokeStyle(lineWidth: lineWidth * 1.4, lineCap: .round, lineJoin: .round))

            // 3. Twinkling sparkles scattered along the edge.
            let count = max(8, Int(Double(baseSparkles) * style.density))
            var sparkleCtx = ctx
            sparkleCtx.blendMode = .plusLighter
            for i in 0..<count {
                let seed = Double(i) * 0.6180339887              // golden-ratio spread
                let u = (seed + hash(i, 1) * 0.02).truncatingRemainder(dividingBy: 1)
                let speed = 0.7 + hash(i, 2) * 1.6
                let phaseOffset = hash(i, 3) * .pi * 2
                let twinkle = pow(max(0, sin(time * speed * 2 + phaseOffset)), 6)   // sharp, mostly-off flashes
                guard twinkle > 0.02 else { continue }
                let point = pointOnPerimeter(u, rect: rect, radius: radius)
                let jitter = CGFloat(hash(i, 4) - 0.5) * lineWidth * 2.2
                let p = CGPoint(x: point.x + jitter * 0.5, y: point.y + jitter * 0.5)
                let color = style.sparkleColors[i % style.sparkleColors.count]
                let sizeMax = lineWidth * (1.6 + CGFloat(hash(i, 5)) * 2.2)
                let s = sizeMax * CGFloat(twinkle)
                let alpha = twinkle * style.intensity

                // Glow dot
                let glow = Path(ellipseIn: CGRect(x: p.x - s * 0.55, y: p.y - s * 0.55, width: s * 1.1, height: s * 1.1))
                sparkleCtx.fill(glow, with: .color(color.opacity(alpha * 0.55)))

                // Four-point star
                var star = Path()
                star.move(to: CGPoint(x: p.x - s, y: p.y)); star.addLine(to: CGPoint(x: p.x + s, y: p.y))
                star.move(to: CGPoint(x: p.x, y: p.y - s)); star.addLine(to: CGPoint(x: p.x, y: p.y + s))
                sparkleCtx.stroke(star, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: max(0.6, s * 0.22), lineCap: .round))
                if s > lineWidth * 1.4 {
                    var diag = Path()
                    let d = s * 0.45
                    diag.move(to: CGPoint(x: p.x - d, y: p.y - d)); diag.addLine(to: CGPoint(x: p.x + d, y: p.y + d))
                    diag.move(to: CGPoint(x: p.x + d, y: p.y - d)); diag.addLine(to: CGPoint(x: p.x - d, y: p.y + d))
                    sparkleCtx.stroke(diag, with: .color(.white.opacity(alpha * 0.6)), style: StrokeStyle(lineWidth: max(0.5, s * 0.14), lineCap: .round))
                }
            }
        }
    }

    /// Deterministic pseudo-random number in 0..<1 for sparkle `i` and channel `k`.
    private func hash(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - floor(x)
    }

    /// A point on the rounded rectangle's outline for `u` in 0..<1, walking clockwise from the top-left corner.
    private func pointOnPerimeter(_ u: Double, rect: CGRect, radius r: CGFloat) -> CGPoint {
        let w = rect.width, h = rect.height
        let straightW = max(0, w - 2 * r), straightH = max(0, h - 2 * r)
        let arc = CGFloat.pi / 2 * r
        let total = 2 * straightW + 2 * straightH + 4 * arc
        var d = CGFloat(u) * total

        // Top edge
        if d < straightW { return CGPoint(x: rect.minX + r + d, y: rect.minY) }
        d -= straightW
        if d < arc { let a = d / max(r, 0.001); return CGPoint(x: rect.maxX - r + r * sin(a), y: rect.minY + r - r * cos(a)) }
        d -= arc
        // Right edge
        if d < straightH { return CGPoint(x: rect.maxX, y: rect.minY + r + d) }
        d -= straightH
        if d < arc { let a = d / max(r, 0.001); return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.maxY - r + r * sin(a)) }
        d -= arc
        // Bottom edge
        if d < straightW { return CGPoint(x: rect.maxX - r - d, y: rect.maxY) }
        d -= straightW
        if d < arc { let a = d / max(r, 0.001); return CGPoint(x: rect.minX + r - r * sin(a), y: rect.maxY - r + r * cos(a)) }
        d -= arc
        // Left edge
        if d < straightH { return CGPoint(x: rect.minX, y: rect.maxY - r - d) }
        d -= straightH
        let a = min(d, arc) / max(r, 0.001)
        return CGPoint(x: rect.minX + r - r * cos(a), y: rect.minY + r - r * sin(a))
    }
}

extension View {
    /// Overlays the rarity's glitter border, if it has one.
    @ViewBuilder
    func glitterBorder(for rarity: Rarity, cornerRadius: CGFloat, lineWidth: CGFloat = 2.5, sparkles: Int = 40, enabled: Bool = true, opacity: Double = 1) -> some View {
        if enabled, let style = rarity.glitter {
            self.overlay {
                GlitterBorder(style: style, cornerRadius: cornerRadius, lineWidth: lineWidth, baseSparkles: sparkles, opacity: opacity)
            }
        } else {
            self
        }
    }
}
