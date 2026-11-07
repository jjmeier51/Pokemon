import SwiftUI

/// A 3×3 binder page.
struct BinderPageView: View {
    let page: BinderPage
    let totalPages: Int
    let highlightedCardID: String?
    let open: (Card) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: BinderLayout.columns)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(page.slots.enumerated()), id: \.offset) { index, card in
                    BinderSlotView(card: card, slotNumber: index + 1, highlighted: card != nil && card?.id == highlightedCardID, open: open)
                }
            }
            .padding(14)
            HStack {
                // Binder rings on the spine side
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(Color.white.opacity(0.18)).frame(width: 6, height: 6)
                    }
                }
                Spacer()
                Text("Page \(page.number) of \(totalPages)")
                    .font(PokeTheme.mono(10))
                    .foregroundStyle(PokeTheme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(colors: [PokeTheme.panelLight, PokeTheme.panel, PokeTheme.deepNavy.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 10)
    }
}
