import SwiftUI

/// One pocket on a binder page.
struct BinderSlotView: View {
    let card: Card?
    let slotNumber: Int
    let highlighted: Bool
    let open: (Card) -> Void

    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    private var collected: Bool { card.map { collection.isCollected($0) } ?? false }

    var body: some View {
        VStack(spacing: 4) {
            pocket
            caption
        }
    }

    // MARK: - Pocket

    private var pocket: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
            if let card {
                CardImageView(card: card, maxPixelSize: 360, cornerRadius: 7)
                    .saturation(collected ? 1 : 0.05)
                    .opacity(collected ? 1 : 0.32)
                    .padding(2)
                if !collected {
                    VStack(spacing: 2) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 18, weight: .bold))
                        Text(card.displayNumber)
                            .font(PokeTheme.mono(9))
                    }
                    .foregroundStyle(PokeTheme.textSecondary)
                    .padding(6)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else {
                Text("\(slotNumber)")
                    .font(PokeTheme.mono(11))
                    .foregroundStyle(PokeTheme.textTertiary.opacity(0.6))
            }
        }
        .aspectRatio(0.716, contentMode: .fit)
        .overlay {
            if collected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(PokeTheme.goldGradient, lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(card == nil ? 0.12 : 0.28), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            }
        }
        .overlay(alignment: .topTrailing) {
            if collected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(PokeTheme.navy, PokeTheme.yellow)
                    .padding(4)
            }
        }
        .modifier(SlotGlitter(card: card, collected: collected, enabled: settings.sparkleEffects))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(PokeTheme.yellow, lineWidth: 3)
                    .shadow(color: PokeTheme.yellow.opacity(0.8), radius: 10)
            }
        }
        .shadow(color: collected ? PokeTheme.gold.opacity(0.25) : .clear, radius: 6, y: 3)
        .scaleEffect(highlighted ? 1.06 : 1)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: highlighted)
        .contentShape(Rectangle())
        .onTapGesture { if let card { open(card) } }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard let card else { return }
            let willCollect = !collected
            withAnimation(.spring(duration: 0.35, bounce: 0.4)) { collection.toggle(card) }
            if willCollect { Haptics.success(enabled: settings.hapticsEnabled) } else { Haptics.impact(.light, enabled: settings.hapticsEnabled) }
        }
        .accessibilityLabel(card.map { "\($0.name), \($0.displayNumber), pocket \(slotNumber), \(collected ? "collected" : "missing")" } ?? "Empty pocket \(slotNumber)")
    }

    // MARK: - Caption

    @ViewBuilder
    private var caption: some View {
        if let card {
            HStack(spacing: 3) {
                Text(card.displayNumber)
                    .font(PokeTheme.mono(9))
                    .foregroundStyle(PokeTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                if collected {
                    let grading = collection.entry(for: card)?.grading
                    if let grading {
                        Text(grading.title)
                            .font(.system(size: 7.5, weight: .black, design: .rounded))
                            .padding(.horizontal, 3.5).padding(.vertical, 1.5)
                            .foregroundStyle(prices.isValuedAtGrade(card, grading: grading) ? Color(hex: 0x0B0B0B) : PokeTheme.textSecondary)
                            .background {
                                if prices.isValuedAtGrade(card, grading: grading) { Capsule().fill(PokeTheme.goldGradient) } else { Capsule().fill(Color.white.opacity(0.12)) }
                            }
                    }
                    if let value = prices.value(of: card, grading: grading) {
                        Text(value.usd)
                            .font(PokeTheme.caption(9))
                            .foregroundStyle(PokeTheme.yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else {
                    Text("Need")
                        .font(PokeTheme.caption(9))
                        .foregroundStyle(PokeTheme.red.opacity(0.9))
                }
            }
            .frame(height: 12)
        } else {
            Text(" ").font(PokeTheme.caption(9)).frame(height: 12)
        }
    }
}

/// Glitter on collected rare pockets, sized for a small cell.
private struct SlotGlitter: ViewModifier {
    let card: Card?
    let collected: Bool
    let enabled: Bool

    func body(content: Content) -> some View {
        if let card, collected {
            content.glitterBorder(for: card.rarity, cornerRadius: 8, lineWidth: 1.6, sparkles: 16, enabled: enabled)
        } else {
            content
        }
    }
}
