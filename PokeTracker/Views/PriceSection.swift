import SwiftUI

/// Shows the latest market value and most recent average sale from every price source.
struct PriceSection: View {
    let card: Card

    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MARKET VALUE")
                    .font(PokeTheme.caption(11)).tracking(1)
                    .foregroundStyle(PokeTheme.textTertiary)
                Spacer()
                if let updated = prices.prices(for: card)?.updatedAt {
                    Text("Updated \(updated, style: .relative) ago")
                        .font(PokeTheme.caption(10))
                        .foregroundStyle(PokeTheme.textTertiary)
                }
            }
            ForEach(PriceSource.allCases) { source in
                sourceCard(source)
            }
        }
        .padding(16)
        .panel()
    }

    @ViewBuilder
    private func sourceCard(_ source: PriceSource) -> some View {
        let quote = prices.prices(for: card)?.quote(for: source)
        let error = prices.error(for: card, source: source)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: source == .tcgplayer ? "cart.fill" : "chart.line.uptrend.xyaxis")
                        .foregroundStyle(source == .tcgplayer ? PokeTheme.brightBlue : Color(hex: 0x2ED573))
                    Text(source.title).font(PokeTheme.headline(15))
                }
                Spacer()
                if let value = quote?.headlinePrice {
                    Text(value.usd)
                        .font(PokeTheme.display(24))
                        .foregroundStyle(PokeTheme.yellow)
                        .contentTransition(.numericText())
                } else if prices.isLoading(card) {
                    ProgressView().tint(PokeTheme.yellow)
                } else {
                    Text("—").font(PokeTheme.display(24)).foregroundStyle(PokeTheme.textTertiary)
                }
            }

            if let quote {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source == .tcgplayer ? "Market price" : "CL Value")
                            .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                        if let trend = quote.trendPercent {
                            Label(String(format: "%+.1f%% · 30d", trend), systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(PokeTheme.caption(11))
                                .foregroundStyle(trend >= 0 ? Color(hex: 0x2ED573) : PokeTheme.red)
                        }
                        if let note = quote.note {
                            Text(note).font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Most recent avg. sale").font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                        if let avg = quote.latestSaleAverage {
                            Text(avg.usd).font(PokeTheme.headline(16))
                            HStack(spacing: 4) {
                                if let count = quote.latestSaleCount { Text("\(count) sold") }
                                if let date = quote.latestSaleDate { Text("· \(date.formatted(date: .abbreviated, time: .omitted))") }
                            }
                            .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                            if let low = quote.latestSaleLow, let high = quote.latestSaleHigh, low != high {
                                Text("\(low.usd) – \(high.usd)").font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                            }
                        } else {
                            Text("No sales yet").font(PokeTheme.body(13)).foregroundStyle(PokeTheme.textSecondary)
                        }
                    }
                }
                if !quote.history.isEmpty {
                    Sparkline(points: quote.history, tint: source == .tcgplayer ? PokeTheme.brightBlue : Color(hex: 0x2ED573))
                        .frame(height: 44)
                }
                if let total = quote.trailingSalesCount, total > 0 {
                    Text("\(total) sales in the last 30 days")
                        .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                }
            } else if let error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PokeTheme.yellow)
                    Text(error).font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
                }
            } else if !prices.isLoading(card) {
                Text("Tap refresh to load prices.").font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textTertiary)
            }

            if let url = quote?.listingURL ?? fallbackURL(source) {
                Button {
                    openURL(url)
                } label: {
                    Label("Open on \(source.title)", systemImage: "arrow.up.right.square")
                        .font(PokeTheme.caption(12))
                        .foregroundStyle(PokeTheme.brightBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fallbackURL(_ source: PriceSource) -> URL? {
        switch source {
        case .tcgplayer:
            if let url = card.tcgplayerURL { return url }
            var components = URLComponents(string: "https://www.tcgplayer.com/search/pokemon/product")!
            components.queryItems = [URLQueryItem(name: "q", value: card.marketplaceQuery)]
            return components.url
        case .cardladder:
            var components = URLComponents(string: "https://app.cardladder.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: card.marketplaceQuery)]
            return components.url
        }
    }
}
