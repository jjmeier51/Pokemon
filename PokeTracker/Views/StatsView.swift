import SwiftUI

struct StatsView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(CollectionStore.self) private var collection
    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings

    @State private var refreshing = false

    private var currentSet: CardSet { catalog.selectedSet(id: settings.selectedSetID) }
    private var owned: [Card] { currentSet.cards.filter { collection.isCollected($0) } }
    private var missing: [Card] { currentSet.cards.filter { !collection.isCollected($0) } }

    var body: some View {
        NavigationStack {
            ZStack {
                PokeTheme.background
                ScrollView {
                    VStack(spacing: 16) {
                        SetSwitcher()
                            .padding(.top, 8)
                        overview
                        valuePanel
                        breakdown(title: "By section", rows: currentSet.sections.map { BreakdownRow(title: $0.title, cards: currentSet.cards(in: $0), tint: PokeTheme.brightBlue) })
                        breakdown(title: "By rarity", rows: currentSet.rarities.map { BreakdownRow(title: $0.title, cards: currentSet.cards(of: $0), tint: $0.color) })
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
                        if let progress = prices.bulkProgress ?? prices.gradedBulkProgress {
                            Text("\(progress.done)/\(progress.total)").font(PokeTheme.mono(12))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(prices.bulkProgress != nil || prices.gradedBulkProgress != nil)
                }
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card, siblings: missing)
            }
        }
    }

    private func refreshAll() async {
        await prices.refreshAll(currentSet.cards, settings: settings, onlyStale: false)
        let gradedOwned = owned.filter { collection.entry(for: $0)?.grading != nil }
        await prices.refreshGradedAll(gradedOwned, onlyStale: false)
    }

    private var overview: some View {
        let total = currentSet.cards.count
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
            Text(progress >= 1 ? "Master set complete!" : "\(Int((progress * 100).rounded()))% of the \(currentSet.shortName) master set")
                .font(PokeTheme.headline(15))
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                stat("Collected", "\(count)", PokeTheme.yellow)
                stat("Missing", "\(total - count)", PokeTheme.red)
                stat("Graded", "\(owned.filter { collection.entry(for: $0)?.grading != nil }.count)", Color(hex: 0xFF5C8A))
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
        let ownedValues = owned.compactMap { prices.value(of: $0, grading: collection.entry(for: $0)?.grading) }
        let ownedPriced = ownedValues
        let missingPriced = missing.filter { prices.value(of: $0) != nil }
        return VStack(alignment: .leading, spacing: 12) {
            Text("COLLECTION VALUE")
                .font(PokeTheme.caption(11)).tracking(1)
                .foregroundStyle(PokeTheme.textTertiary)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ownedValues.reduce(0, +).usd)
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
            gradedValuationStatus
            if let last = prices.lastUpdated {
                Text("Raw cards at TCGplayer market price · graded cards at PriceCharting's value for their grade · updated \(last, style: .relative) ago")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
            } else {
                Text("Tap refresh to load TCGplayer market prices for every card.")
                    .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
            }
        }
        .padding(16)
        .panel()
    }

    @ViewBuilder
    private var gradedValuationStatus: some View {
        let gradedOwned = owned.filter { collection.entry(for: $0)?.grading != nil }
        if !gradedOwned.isEmpty {
            let atGrade = gradedOwned.filter { prices.isValuedAtGrade($0, grading: collection.entry(for: $0)?.grading) }.count
            HStack(spacing: 8) {
                Image(systemName: atGrade == gradedOwned.count ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                    .foregroundStyle(atGrade == gradedOwned.count ? Color(hex: 0x2ED573) : PokeTheme.yellow)
                if let progress = prices.gradedBulkProgress {
                    Text("Loading graded values… \(progress.done)/\(progress.total)")
                } else if atGrade == gradedOwned.count {
                    Text("All \(gradedOwned.count) graded cards valued at their grade")
                } else {
                    let failed = gradedOwned.filter { prices.gradedError(for: $0) != nil }.count
                    Text("\(atGrade) of \(gradedOwned.count) graded cards valued at their grade · \(gradedOwned.count - atGrade) still at raw price" + (failed > 0 ? " · \(failed) PriceCharting lookups failed" : ""))
                }
                Spacer()
                if prices.gradedBulkProgress == nil, atGrade < gradedOwned.count {
                    Button("Fetch") { Task { await prices.refreshGradedAll(gradedOwned, onlyStale: false) } }
                        .font(PokeTheme.caption(12)).foregroundStyle(PokeTheme.yellow)
                }
            }
            .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
        }
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
                                .glitterBorder(for: card.rarity, cornerRadius: 6, lineWidth: 1.4, sparkles: 14, enabled: settings.sparkleEffects)
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
