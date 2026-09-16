import SwiftUI

struct CardDetailView: View {
    let card: Card
    var siblings: [Card] = []

    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    @State private var showNoteEditor = false
    @State private var noteDraft = ""

    private var collected: Bool { collection.isCollected(card) }

    var body: some View {
        ZStack {
            PokeTheme.background
            ScrollView {
                VStack(spacing: 20) {
                    artwork
                    titleBlock
                    collectButton
                    if collected { ownershipPanel }
                    PriceSection(card: card)
                    detailsPanel
                    if let attacks = card.attacks, !attacks.isEmpty { attacksPanel(attacks) }
                    if let notes = card.notes { infoPanel(title: "About this card", text: notes) }
                    if let flavor = card.flavorText, !flavor.isEmpty { infoPanel(title: "Pokédex entry", text: flavor, italic: true) }
                    neighbors
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(card.displayNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PokeTheme.deepNavy.opacity(0.9), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    prices.refresh(card, settings: settings)
                } label: {
                    if prices.isLoading(card) { ProgressView().tint(PokeTheme.yellow) } else { Image(systemName: "arrow.clockwise") }
                }
                .accessibilityLabel("Refresh prices")
            }
        }
        .task(id: card.id) {
            if settings.autoRefreshPrices { prices.refreshIfStale(card, settings: settings) }
        }
    }

    // MARK: - Sections

    private var artwork: some View {
        FlipCardView(card: card, dimmed: collected && settings.dimCollectedCards)
            .frame(maxWidth: 340)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.4), value: collected)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if let type = card.energyType { EnergyChip(type: type, size: 26) }
                Text(card.name)
                    .font(PokeTheme.display(28))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let hp = card.hp {
                    Text("HP \(hp)")
                        .font(PokeTheme.mono(13))
                        .foregroundStyle(PokeTheme.textSecondary)
                }
            }
            HStack(spacing: 8) {
                RarityBadge(rarity: card.rarity)
                Text(card.section.title)
                    .font(PokeTheme.caption(11))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
            if let origin = card.classicOrigin {
                Text("Originally \(origin.setName) · \(origin.number) · \(String(origin.year))")
                    .font(PokeTheme.body(13))
                    .foregroundStyle(PokeTheme.textSecondary)
            }
            if let artist = card.artist {
                Text("Illustrated by \(artist)")
                    .font(PokeTheme.body(13))
                    .foregroundStyle(PokeTheme.textSecondary)
            }
        }
    }

    private var collectButton: some View {
        Button {
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { collection.toggle(card) }
            if collection.isCollected(card) { Haptics.success(enabled: settings.hapticsEnabled) } else { Haptics.impact(.light, enabled: settings.hapticsEnabled) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: collected ? "checkmark.seal.fill" : "plus.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(collected ? "In your collection" : "Add to collection")
                    .font(PokeTheme.headline(17))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(collected ? PokeTheme.navy : .white)
            .background {
                if collected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PokeTheme.goldGradient)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [PokeTheme.brightBlue, PokeTheme.blue], startPoint: .top, endPoint: .bottom))
                }
            }
            .shadow(color: (collected ? PokeTheme.gold : PokeTheme.blue).opacity(0.45), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var ownershipPanel: some View {
        let entry = collection.entry(for: card)
        return VStack(spacing: 12) {
            HStack {
                Label("Quantity", systemImage: "square.stack.3d.up.fill")
                    .font(PokeTheme.headline(14))
                Spacer()
                Stepper(value: Binding(get: { collection.quantity(of: card) }, set: { collection.setQuantity(card, $0) }), in: 1...99) {
                    Text("\(collection.quantity(of: card))")
                        .font(PokeTheme.mono(16))
                        .frame(minWidth: 28)
                }
                .fixedSize()
            }
            if let date = entry?.collectedAt {
                HStack {
                    Label("Collected", systemImage: "calendar")
                        .font(PokeTheme.headline(14))
                    Spacer()
                    Text(date, style: .date).font(PokeTheme.body(14)).foregroundStyle(PokeTheme.textSecondary)
                }
            }
            HStack {
                Label("Favorite", systemImage: "heart.fill")
                    .font(PokeTheme.headline(14))
                Spacer()
                Toggle("", isOn: Binding(get: { entry?.favorite ?? false }, set: { collection.setFavorite(card, $0) }))
                    .labelsHidden()
                    .tint(PokeTheme.red)
            }
            Button {
                noteDraft = entry?.note ?? ""
                showNoteEditor = true
            } label: {
                HStack {
                    Label("Note", systemImage: "note.text")
                        .font(PokeTheme.headline(14))
                    Spacer()
                    Text((entry?.note.isEmpty ?? true) ? "Add a note (grade, condition…)" : entry!.note)
                        .font(PokeTheme.body(13))
                        .foregroundStyle(PokeTheme.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(PokeTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .panel()
        .alert("Card note", isPresented: $showNoteEditor) {
            TextField("Condition, grade, where you got it…", text: $noteDraft)
            Button("Save") { collection.setNote(card, noteDraft) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARD DETAILS")
                .font(PokeTheme.caption(11)).tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                detail("Number", card.displayNumber)
                detail("Rarity", card.rarity.title)
                detail("Set", card.section == .classic ? "Classic Collection" : "30th Celebration")
                if let stage = card.stage { detail("Stage", stage) }
                if let type = card.energyType { detail("Type", type.title) }
                if let weakness = card.weakness, !weakness.isEmpty { detail("Weakness", weakness) }
                if let resistance = card.resistance, !resistance.isEmpty { detail("Resistance", resistance) }
                if let retreat = card.retreatCost, !retreat.isEmpty { detail("Retreat", retreat) }
                if let artist = card.artist { detail("Artist", artist) }
                if let origin = card.classicOrigin { detail("Original set", "\(origin.setName) (\(String(origin.year)))") }
            }
            if let ability = card.ability, !ability.isEmpty {
                Divider().overlay(Color.white.opacity(0.1))
                Text(ability)
                    .font(PokeTheme.body(13))
                    .foregroundStyle(PokeTheme.textSecondary)
            }
        }
        .padding(16)
        .panel()
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(PokeTheme.caption(10)).tracking(0.8).foregroundStyle(PokeTheme.textTertiary)
            Text(value).font(PokeTheme.body(14)).foregroundStyle(PokeTheme.textPrimary)
        }
    }

    private func attacksPanel(_ attacks: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ATTACKS")
                .font(PokeTheme.caption(11)).tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            ForEach(Array(attacks.enumerated()), id: \.offset) { _, attack in
                let parts = attack.split(separator: "\n", maxSplits: 1).map(String.init)
                VStack(alignment: .leading, spacing: 3) {
                    Text(parts.first ?? attack).font(PokeTheme.headline(14))
                    if parts.count > 1 {
                        Text(parts[1]).font(PokeTheme.body(13)).foregroundStyle(PokeTheme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panel()
    }

    private func infoPanel(title: String, text: String, italic: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(PokeTheme.caption(11)).tracking(1).foregroundStyle(PokeTheme.textTertiary)
            Text(text)
                .font(PokeTheme.body(13))
                .italic(italic)
                .foregroundStyle(PokeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panel()
    }

    @ViewBuilder
    private var neighbors: some View {
        if let index = siblings.firstIndex(of: card), siblings.count > 1 {
            HStack(spacing: 12) {
                if index > 0 {
                    NavigationLink(value: siblings[index - 1]) {
                        neighborLabel(siblings[index - 1], systemImage: "chevron.left", leading: true)
                    }
                }
                if index < siblings.count - 1 {
                    NavigationLink(value: siblings[index + 1]) {
                        neighborLabel(siblings[index + 1], systemImage: "chevron.right", leading: false)
                    }
                }
            }
            .buttonStyle(.plain)
            .navigationDestination(for: Card.self) { next in
                CardDetailView(card: next, siblings: siblings)
            }
        }
    }

    private func neighborLabel(_ card: Card, systemImage: String, leading: Bool) -> some View {
        HStack(spacing: 8) {
            if leading { Image(systemName: systemImage).font(.system(size: 12, weight: .bold)) }
            VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
                Text(card.displayNumber).font(PokeTheme.mono(10)).foregroundStyle(PokeTheme.textTertiary)
                Text(card.name).font(PokeTheme.caption(13)).lineLimit(1)
            }
            if !leading { Image(systemName: systemImage).font(.system(size: 12, weight: .bold)) }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
