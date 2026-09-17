import SwiftUI

/// Graded market values and the most recent graded sale for a chosen company + grade (PriceCharting).
struct GradedPriceSection: View {
    let card: Card

    @Environment(PriceCenter.self) private var prices
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    private var company: GradingCompany { settings.preferredGradingCompany }
    private var grade: Double { settings.preferredGrade }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GRADED VALUE")
                    .font(PokeTheme.caption(11)).tracking(1)
                    .foregroundStyle(PokeTheme.textTertiary)
                Spacer()
                if prices.isGradedLoading(card) {
                    ProgressView().tint(PokeTheme.yellow).controlSize(.small)
                } else if let quote = prices.gradedQuote(for: card) {
                    Text("PriceCharting · \(quote.fetchedAt, style: .relative) ago")
                        .font(PokeTheme.caption(10))
                        .foregroundStyle(PokeTheme.textTertiary)
                }
            }

            pickers

            if let quote = prices.gradedQuote(for: card) {
                results(quote)
            } else if let error = prices.gradedError(for: card) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PokeTheme.yellow)
                    Text(error).font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
                    Spacer()
                    Button("Retry") { prices.refreshGraded(card) }
                        .font(PokeTheme.caption(12)).foregroundStyle(PokeTheme.yellow)
                }
            } else if !prices.isGradedLoading(card) {
                Text("Loading graded prices…").font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textTertiary)
            }
        }
        .padding(16)
        .panel()
    }

    private var pickers: some View {
        @Bindable var settings = settings
        return VStack(spacing: 10) {
            Picker("Grading company", selection: $settings.preferredGradingCompany) {
                ForEach(GradingCompany.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.preferredGradingCompany) { _, company in
                if !company.grades.contains(settings.preferredGrade) { settings.preferredGrade = 10 }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(company.grades, id: \.self) { g in
                        let selected = g == grade
                        Button {
                            Haptics.selection(enabled: settings.hapticsEnabled)
                            settings.preferredGrade = g
                        } label: {
                            Text(Grade.label(g))
                                .font(PokeTheme.caption(13))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .foregroundStyle(selected ? Color(hex: 0x0B0B0B) : PokeTheme.textPrimary)
                                .background {
                                    if selected { Capsule().fill(PokeTheme.goldGradient) } else { Capsule().fill(Color.white.opacity(0.08)) }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func results(_ quote: GradedQuote) -> some View {
        let latest = quote.latestSale(company: company, grade: grade)
        let guide = quote.guideValue(company: company, grade: grade)
        let recent = quote.recentSales(company: company, grade: grade, limit: 4)

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Most recent \(company.title) \(Grade.label(grade)) sale")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                if let latest {
                    Text(latest.price.usd)
                        .font(PokeTheme.display(26))
                        .foregroundStyle(PokeTheme.yellow)
                        .contentTransition(.numericText())
                    Text(latest.date.formatted(date: .abbreviated, time: .omitted) + (latest.source.map { " · \($0)" } ?? ""))
                        .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                } else {
                    Text("—").font(PokeTheme.display(26)).foregroundStyle(PokeTheme.textTertiary)
                    Text("No \(company.title) \(Grade.label(grade)) sales tracked yet")
                        .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(guide.map { "\($0.label) market value" } ?? "Market value")
                    .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                Text(guide?.value.usd ?? "—")
                    .font(PokeTheme.headline(18))
                if let ungraded = quote.ungraded {
                    Text("Raw \(ungraded.usd)")
                        .font(PokeTheme.caption(10)).foregroundStyle(PokeTheme.textTertiary)
                }
            }
        }

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(recent) { sale in
                    HStack(alignment: .top, spacing: 8) {
                        Text(sale.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(PokeTheme.mono(10)).foregroundStyle(PokeTheme.textTertiary)
                            .frame(width: 46, alignment: .leading)
                        Text(sale.title)
                            .font(PokeTheme.caption(11)).foregroundStyle(PokeTheme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(sale.price.usd).font(PokeTheme.caption(12))
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        Button {
            openURL(quote.pageURL)
        } label: {
            Label("Open on PriceCharting", systemImage: "arrow.up.right.square")
                .font(PokeTheme.caption(12))
                .foregroundStyle(PokeTheme.brightBlue)
        }
        .buttonStyle(.plain)
    }
}
