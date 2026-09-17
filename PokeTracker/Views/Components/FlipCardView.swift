import SwiftUI

/// Shows the card back first, then flips over to reveal the artwork. Tap to flip again.
/// The flip runs in two halves (turn to the edge, swap faces, finish the turn) so the
/// hidden face is never drawn mirrored.
struct FlipCardView: View {
    let card: Card
    var dimmed = false
    var sparkle = true

    @State private var showingFront = false
    @State private var angle: Double = 0
    @State private var flipping = false
    @State private var didIntroFlip = false

    private let halfDuration = 0.32

    var body: some View {
        ZStack {
            if showingFront {
                CardImageView(card: card, full: true, cornerRadius: 18)
                    .saturation(dimmed ? 0.15 : 1)
                    .glitterBorder(for: card.rarity, cornerRadius: 18, lineWidth: 3.5, sparkles: 70, enabled: sparkle, opacity: dimmed ? 0.5 : 1)
                    .tiltCard(rarity: card.rarity, enabled: !flipping)
            } else {
                Image("CardBack")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 18, y: 12)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .contentShape(Rectangle())
        .onTapGesture { flip() }
        .onAppear {
            guard !didIntroFlip else { return }
            didIntroFlip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { flip() }
        }
        .accessibilityLabel(showingFront ? "\(card.name), tap to flip to the back" : "Card back, tap to flip to the front")
        .accessibilityAddTraits(.isButton)
    }

    private func flip() {
        guard !flipping else { return }
        flipping = true
        // First half: rotate the visible face away until it's edge-on.
        withAnimation(.easeIn(duration: halfDuration)) { angle = 90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + halfDuration) {
            // Swap faces while edge-on, then finish the turn from the other side.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showingFront.toggle()
                angle = -90
            }
            withAnimation(.easeOut(duration: halfDuration)) { angle = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + halfDuration) { flipping = false }
        }
    }
}
