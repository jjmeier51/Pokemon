import SwiftUI

struct StatsView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    @State private var refreshing = false

    private var owned: [Card] { catalog.cards.filter { collection.isCollected($0) } }
    private var missing: [Card] { catalog.cards.filter { !collection.isCollected($0) } }

    var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.background
                ScrollView {
                    VStack(spacing: 16) {
                        overview
                        valuePanel
                        breakdown(title: "By section", rows: CardSection.allCases.map { BreakdownRow(title: $0.title, cards: catalog.cards(in: $0), tint: PokeTheme.brightBlue) })
                        breakdown(title: "By rarity", rows: catalog.rarities.map { BreakdownRow(title: $0.title, cards: catalog.cards(of: $0), tint: $0.color) })
                        topMissing
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Progress")
            .toolbarBackground(PokeTheme.deepNavy.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        if let progress = prices.bulkProgress {
                            Text("\(progress.done)/\(progress.total)").font(PokeTheme.mono(12))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(prices.bulkProgress != nil)
                }
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card, siblings: missing)
            }
        }
    }

    private func refreshAll() async {
        await prices.refreshAll(catalog.cards, settings: settings, onlyStale: false)
    }

    private var overview: some View {
        let total = catalog.cards.count
        let count = owned.count
        let progress = total == 0 ? 0 : Double(count) / Double(total)
        return VStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 16)
                    .frame(width: 170, height: 170)
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(PokeTheme.display(44))
                    Text("of \(total)")
                        .font(PokeTheme.body(14))
                        .foregroundStyle(PokeTheme.textSecondary)
                }
            }
            Text(progress >= 1 ? "Master set complete!" : "\(Int((progress * 100).rounded()))% of the 30th Celebration master set")
                .font(PokeTheme.headline(15))
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                stat("Collected", "\(count)", PokeTheme.yellow)
                stat("Missing", "\(total - count)", PokeTheme.red)
                stat("Favorites", "\(collection.entries.values.filter(\.favorite).count)", Color(hex: 0xFF5C8A))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .panel()
        .padding(.top, 8)
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(PokeTheme.title(20)).foregroundStyle(tint)
            Text(label.uppercased()).font(PokeTheme.caption(10)).tracking(0.8).foregroundStyle(PokeTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var valuePanel: some View {
        let ownedPriced = owned.filter { prices.value(of: $0) != nil }
        let missingPriced = missing.filter { prices.value(of: $0) != nil }
        return VStack(alignment: .leading, spacing: 12) {
            Text("COLLECTION VALUE")
                .font(PokeTheme.caption(11)).tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prices.totalValue(of: ownedPriced).usd)
                        .font(PokeTheme.display(30))
                        .foregroundStyle(PokeTheme.yellow)
                    Text("Owned · \(ownedPriced.count) of \(owned.count) priced")
                        .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(prices.totalValue(of: missingPriced).usd)
                        .font(PokeTheme.title(22))
                        .foregroundStyle(PokeTheme.textPrimary)
                    Text("To complete · \(missingPriced.count) of \(missing.count) priced")
                        .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textTertiary)
                }
            }
            if let last = prices.lastUpdated {
                Text("TCGplayer market prices · updated \(last, style: .relative) ago")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
            } else {
                Text("Tap refresh to load TCGplayer market prices for every card.")
                    .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
            }
        }
        .padding(16)
        .panel()
    }

    private func breakdown(title: String, rows: [BreakdownRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(PokeTheme.caption(11)).tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            ForEach(rows) { row in
                let count = collection.collectedCount(in: row.cards)
                VStack(spacing: 6) {
                    HStack {
                        Text(row.title).font(PokeTheme.headline(14))
                        Spacer()
                        Text("\(count)/\(row.cards.count)").font(PokeTheme.mono(12)).foregroundStyle(PokeTheme.textSecondary)
                    }
                    ProgressBar(progress: row.cards.isEmpty ? 0 : Double(count) / Double(row.cards.count), tint: row.tint)
                }
            }
        }
        .padding(16)
        .panel()
    }

    @ViewBuilder
    private var topMissing: some View {
        let ranked = missing.compactMap { card -> RankedCard? in
            guard let value = prices.value(of: card) else { return nil }
            return RankedCard(card: card, value: value)
        }.sorted { $0.value > $1.value }.prefix(5)
        if !ranked.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("BIGGEST CHASE CARDS STILL MISSING")
                    .font(PokeTheme.caption(11)).tracking(1)
                    .foregroundStyle(PokeTheme.textTertiary)
                ForEach(Array(ranked)) { item in
                    let card = item.card
                    let value = item.value
                    NavigationLink(value: card) {
                        HStack(spacing: 12) {
                            CardImageView(card: card, maxPixelSize: 200, cornerRadius: 6)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name).font(PokeTheme.headline(14))
                                HStack(spacing: 6) {
                                    Text(card.displayNumber).font(PokeTheme.mono(10)).foregroundStyle(PokeTheme.textTertiary)
                                    RarityBadge(rarity: card.rarity, compact: true)
                                }
                            }
                            Spacer()
                            Text(value.usd).font(PokeTheme.headline(15)).foregroundStyle(PokeTheme.yellow)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(PokeTheme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .panel()
        }
    }
}

private struct BreakdownRow: Identifiable {
    let title: String
    let cards: [Card]
    let tint: Color
    var id: String { title }
}

private struct RankedCard: Identifiable {
    let card: Card
    let value: Double
    var id: String { card.id }
}
