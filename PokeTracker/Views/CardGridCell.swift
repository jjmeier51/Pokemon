import SwiftUI

struct CardGridCell: View {
    let card: Card
    let open: () -> Void

    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings
    @State private var pulse = false

    private var collected: Bool { collection.isCollected(card) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CardImageView(card: card, maxPixelSize: 520, cornerRadius: 9)
                    .saturation(collected && settings.dimCollectedCards ? 0.05 : 1)
                    .opacity(collected && settings.dimCollectedCards ? 0.55 : 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(collected ? PokeTheme.goldGradient : LinearGradient(colors: [.white.opacity(0.12)], startPoint: .top, endPoint: .bottom), lineWidth: collected ? 2 : 1)
                    }
                    .glitterBorder(for: card.rarity, cornerRadius: 9, lineWidth: 2.2, sparkles: 34,
                                   enabled: settings.sparkleEffects, opacity: collected && settings.dimCollectedCards ? 0.45 : 1)
                    .shadow(color: collected ? PokeTheme.gold.opacity(0.35) : .black.opacity(0.4), radius: collected ? 10 : 6, y: 4)
                    .scaleEffect(pulse ? 1.06 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { open() }

                checkButton
                    .padding(5)
            }
            .padding(.top, 2)

            HStack(alignment: .center, spacing: 4) {
                Text(card.displayNumber)
                    .font(PokeTheme.mono(10))
                    .foregroundStyle(PokeTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if let price = prices.value(of: card) {
                    Text(price.usd)
                        .font(PokeTheme.caption(10))
                        .foregroundStyle(PokeTheme.yellow)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 4) {
                Text(card.name)
                    .font(PokeTheme.caption(12))
                    .foregroundStyle(PokeTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                RarityBadge(rarity: card.rarity, compact: true)
            }
        }
        .contextMenu {
            Button {
                toggle()
            } label: {
                Label(collected ? "Mark as missing" : "Mark as collected", systemImage: collected ? "xmark.circle" : "checkmark.circle")
            }
            Button { open() } label: { Label("View card", systemImage: "eye") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.name), \(card.displayNumber), \(card.rarity.title), \(collected ? "collected" : "missing")")
    }

    private var checkButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(collected ? AnyShapeStyle(PokeTheme.goldGradient) : AnyShapeStyle(Color.black.opacity(0.55)))
                Circle()
                    .strokeBorder(Color.white.opacity(collected ? 0.9 : 0.4), lineWidth: 1.5)
                Image(systemName: collected ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(collected ? PokeTheme.navy : .white)
            }
            .frame(width: 30, height: 30)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(collected ? "Remove from collection" : "Add to collection")
    }

    private func toggle() {
        let willCollect = !collected
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) {
            collection.toggle(card)
            pulse = willCollect
        }
        if willCollect {
            Haptics.success(enabled: settings.hapticsEnabled)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(duration: 0.4)) { pulse = false }
            }
        } else {
            Haptics.impact(.light, enabled: settings.hapticsEnabled)
        }
    }
}
