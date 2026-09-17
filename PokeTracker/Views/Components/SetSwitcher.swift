import SwiftUI

/// Top-of-screen toggle between the tracked expansions.
struct SetSwitcher: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(catalog.sets) { set in
                let selected = set.id == settings.selectedSetID
                Button {
                    guard !selected else { return }
                    Haptics.impact(.medium, enabled: settings.hapticsEnabled)
                    withAnimation(.snappy) { settings.selectedSetID = set.id }
                } label: {
                    HStack(spacing: 8) {
                        Image(set.markAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 18)
                        Text(set.shortName)
                            .font(PokeTheme.caption(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selected ? Color(hex: 0x0B0B0B) : PokeTheme.textPrimary)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PokeTheme.goldGradient)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .accessibilityLabel("Card set")
    }
}
