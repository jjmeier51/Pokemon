import Foundation

enum PriceSource: String, Codable, CaseIterable, Identifiable {
    case tcgplayer
    case cardladder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tcgplayer: return "TCGplayer"
        case .cardladder: return "Card Ladder"
        }
    }
}

struct PricePoint: Codable, Hashable, Identifiable {
    let date: Date
    let price: Double
    let quantitySold: Int

    var id: Date { date }
}

/// A single source's view of a card's value.
struct PriceQuote: Codable, Hashable {
    var source: PriceSource
    /// TCGplayer "Market Price" or Card Ladder "CL Value".
    var marketPrice: Double?
    /// Average price of the most recent day (or sale) with completed sales.
    var latestSaleAverage: Double?
    var latestSaleDate: Date?
    var latestSaleCount: Int?
    var latestSaleLow: Double?
    var latestSaleHigh: Double?
    /// Total sales over the trailing window (TCGplayer: 30 days).
    var trailingSalesCount: Int?
    var history: [PricePoint] = []
    var listingURL: URL?
    var fetchedAt: Date
    var note: String?

    var headlinePrice: Double? { marketPrice ?? latestSaleAverage }

    var trendPercent: Double? {
        let points = history.filter { $0.price > 0 }.sorted { $0.date < $1.date }
        guard let first = points.first, let last = points.last, first.date != last.date, first.price > 0 else { return nil }
        return (last.price - first.price) / first.price * 100
    }
}

struct CardPrices: Codable, Hashable {
    var tcgplayer: PriceQuote?
    var cardladder: PriceQuote?
    var updatedAt: Date

    func quote(for source: PriceSource) -> PriceQuote? {
        switch source {
        case .tcgplayer: return tcgplayer
        case .cardladder: return cardladder
        }
    }

    /// Best available headline value, TCGplayer first.
    var bestValue: Double? {
        tcgplayer?.headlinePrice ?? cardladder?.headlinePrice
    }
}

enum PriceError: LocalizedError {
    case missingAPIKey
    case notFound
    case badResponse(Int)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add a Card Ladder API key in Settings."
        case .notFound: return "No listing found for this card."
        case .badResponse(let code): return "Server responded with HTTP \(code)."
        case .decoding(let detail): return "Unexpected response: \(detail)"
        case .network(let detail): return detail
        }
    }
}

extension Double {
    var usd: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = self >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }
}
