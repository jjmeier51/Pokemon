import SwiftUI

struct RarityBadge: View {
    let rarity: Rarity
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Text(rarity.symbol)
                .font(.system(size: compact ? 9 : 11, weight: .black))
            if !compact {
                Text(rarity.title.uppercased())
                    .font(PokeTheme.caption(10))
                    .tracking(0.6)
            }
        }
        .foregroundStyle(rarity.badgeForeground)
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(rarity.badgeBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .accessibilityLabel(rarity.title)
    }
}

struct EnergyChip: View {
    let type: EnergyType
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: type.symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(type == .darkness ? .white : PokeTheme.navy.opacity(0.85))
            .frame(width: size, height: size)
            .background(type.color, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .accessibilityLabel("\(type.title) type")
    }
}

struct SectionChip: View {
    let title: String
    let systemImage: String?
    let selected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .bold)) }
            Text(title).font(PokeTheme.caption(13))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(selected ? PokeTheme.navy : PokeTheme.textPrimary)
        .background {
            if selected {
                Capsule().fill(PokeTheme.goldGradient)
            } else {
                Capsule().fill(Color.white.opacity(0.08))
            }
        }
        .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: selected ? PokeTheme.gold.opacity(0.35) : .clear, radius: 8, y: 3)
        .animation(.spring(duration: 0.3), value: selected)
    }
}
