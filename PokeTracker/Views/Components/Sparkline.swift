import SwiftUI

/// A small price-history line chart.
struct Sparkline: View {
    let points: [PricePoint]
    var tint: Color = PokeTheme.yellow

    var body: some View {
        GeometryReader { proxy in
            let values = points.map(\.price).filter { $0 > 0 }
            if values.count >= 2, let minV = values.min(), let maxV = values.max() {
                let range = max(maxV - minV, 0.01)
                let stepX = proxy.size.width / CGFloat(max(1, values.count - 1))
                let path = Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = proxy.size.height - CGFloat((value - minV) / range) * (proxy.size.height - 6) - 3
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                ZStack {
                    path
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .shadow(color: tint.opacity(0.5), radius: 4)
                    Path { fill in
                        fill.addPath(path)
                        fill.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: proxy.size.height))
                        fill.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                        fill.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                }
            } else {
                Text("Not enough sales history yet")
                    .font(PokeTheme.caption(11))
                    .foregroundStyle(PokeTheme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
