import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var gradient: AngularGradient = AngularGradient(colors: [PokeTheme.gold, PokeTheme.yellow, Color(hex: 0xFFE27A), PokeTheme.gold], center: .center)

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: PokeTheme.gold.opacity(0.5), radius: 6)
                .animation(.spring(duration: 0.8, bounce: 0.2), value: progress)
        }
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color = PokeTheme.yellow
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, proxy.size.width * max(0, min(1, progress))))
                    .animation(.spring(duration: 0.6), value: progress)
            }
        }
        .frame(height: height)
    }
}
