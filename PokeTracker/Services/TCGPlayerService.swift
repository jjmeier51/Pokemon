import Foundation

/// Reads market data from TCGplayer's public web endpoints (the same ones the tcgplayer.com site uses).
struct TCGPlayerService: Sendable {
    private let session: URLSession

    init(session: URLSession = TCGPlayerService.makeSession()) {
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "application/json"
        ]
        return URLSession(configuration: config)
    }

    // MARK: - Public API

    func quote(for card: Card) async throws -> PriceQuote {
        let productId: Int
        if let id = card.tcgplayerProductId {
            productId = id
        } else {
            productId = try await searchProductId(for: card)
        }

        async let pricePoints = fetchPricePoints(productId: productId)
        async let history = fetchHistory(productId: productId)

        let points = try await pricePoints
        let buckets = (try? await history) ?? []

        var quote = PriceQuote(source: .tcgplayer, fetchedAt: Date())
        quote.listingURL = card.tcgplayerURL ?? URL(string: "https://www.tcgplayer.com/product/\(productId)")

        // Prefer the foil printing (every card in this set is foil), fall back to any priced printing.
        let preferred = points.first { $0.printingType.lowercased().contains("foil") && $0.marketPrice != nil }
            ?? points.first { $0.marketPrice != nil }
        quote.marketPrice = preferred?.marketPrice
        if quote.marketPrice == nil, let median = preferred?.listedMedianPrice ?? points.compactMap(\.listedMedianPrice).first {
            quote.marketPrice = median
            quote.note = "Listed median (no market price yet)"
        }

        let sorted = buckets.sorted { $0.date < $1.date }
        quote.history = sorted.map { PricePoint(date: $0.date, price: $0.marketPrice, quantitySold: $0.quantitySold) }
        quote.trailingSalesCount = sorted.reduce(0) { $0 + $1.quantitySold }
        if let latest = sorted.last(where: { $0.quantitySold > 0 }) {
            quote.latestSaleAverage = latest.averageSale
            quote.latestSaleDate = latest.date
            quote.latestSaleCount = latest.quantitySold
            quote.latestSaleLow = latest.lowSalePrice > 0 ? latest.lowSalePrice : nil
            quote.latestSaleHigh = latest.highSalePrice > 0 ? latest.highSalePrice : nil
        }
        if quote.marketPrice == nil, quote.latestSaleAverage == nil {
            throw PriceError.notFound
        }
        return quote
    }

    // MARK: - Endpoints

    struct PricePointDTO: Decodable {
        let printingType: String
        let marketPrice: Double?
        let buylistMarketPrice: Double?
        let listedMedianPrice: Double?
    }

    func fetchPricePoints(productId: Int) async throws -> [PricePointDTO] {
        let url = URL(string: "https://mpapi.tcgplayer.com/v2/product/\(productId)/pricepoints")!
        let data = try await get(url)
        do {
            return try JSONDecoder().decode([PricePointDTO].self, from: data)
        } catch {
            throw PriceError.decoding("price points")
        }
    }

    struct HistoryBucket {
        let date: Date
        let marketPrice: Double
        let quantitySold: Int
        let lowSalePrice: Double
        let highSalePrice: Double

        /// The average price of the day's sales. TCGplayer only exposes the day's low/high and the rolling
        /// market price, so this uses the midpoint when both are present and the market price otherwise.
        var averageSale: Double {
            if lowSalePrice > 0 && highSalePrice > 0 { return (lowSalePrice + highSalePrice) / 2 }
            return marketPrice
        }
    }

    private struct HistoryResponse: Decodable {
        struct Result: Decodable {
            struct Bucket: Decodable {
                let marketPrice: String?
                let quantitySold: String?
                let lowSalePrice: String?
                let highSalePrice: String?
                let bucketStartDate: String?
            }
            let variant: String?
            let condition: String?
            let buckets: [Bucket]
        }
        let result: [Result]
    }

    func fetchHistory(productId: Int, range: String = "month") async throws -> [HistoryBucket] {
        let url = URL(string: "https://infinite-api.tcgplayer.com/price/history/\(productId)/detailed?range=\(range)")!
        let data = try await get(url)
        let response: HistoryResponse
        do {
            response = try JSONDecoder().decode(HistoryResponse.self, from: data)
        } catch {
            throw PriceError.decoding("price history")
        }
        // Near Mint Holofoil is the canonical variant for this set.
        let result = response.result.first { ($0.condition ?? "").lowercased().contains("near mint") && ($0.variant ?? "").lowercased().contains("holo") }
            ?? response.result.first { ($0.condition ?? "").lowercased().contains("near mint") }
            ?? response.result.first
        guard let result else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        return result.buckets.compactMap { bucket in
            guard let dateString = bucket.bucketStartDate, let date = formatter.date(from: dateString) else { return nil }
            return HistoryBucket(date: date,
                                 marketPrice: Double(bucket.marketPrice ?? "") ?? 0,
                                 quantitySold: Int(bucket.quantitySold ?? "") ?? 0,
                                 lowSalePrice: Double(bucket.lowSalePrice ?? "") ?? 0,
                                 highSalePrice: Double(bucket.highSalePrice ?? "") ?? 0)
        }
    }

    private struct SearchResponse: Decodable {
        struct Result: Decodable {
            struct Product: Decodable {
                struct Attributes: Decodable { let number: String? }
                let productId: Double
                let productName: String
                let customAttributes: Attributes?
            }
            let results: [Product]
        }
        let results: [Result]
    }

    /// Fallback used only when the catalog has no product id for a card.
    func searchProductId(for card: Card) async throws -> Int {
        var components = URLComponents(string: "https://mp-search-api.tcgplayer.com/v1/search/request")!
        components.queryItems = [URLQueryItem(name: "q", value: card.marketplaceQuery), URLQueryItem(name: "isList", value: "false")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.tcgplayer.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.tcgplayer.com/", forHTTPHeaderField: "Referer")
        let body: [String: Any] = [
            "algorithm": "sales_synonym_v2",
            "from": 0,
            "size": 24,
            "filters": ["term": ["productLineName": ["pokemon"]], "range": [:], "match": [:]],
            "listingSearch": ["context": ["cart": [:]], "filters": ["term": ["sellerStatus": "Live", "channelId": 0], "range": ["quantity": ["gte": 1]], "exclude": ["channelExclusion": 0]]],
            "context": ["cart": [:], "shippingCountry": "US"],
            "settings": ["useFuzzySearch": true, "didYouMean": [:]],
            "sort": [:]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PriceError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let products = decoded.results.first?.results ?? []
        let wanted = card.displayNumber.lowercased()
        if let match = products.first(where: { ($0.customAttributes?.number ?? "").lowercased() == wanted }) {
            return Int(match.productId)
        }
        if let match = products.first(where: { $0.productName.lowercased().contains(card.name.lowercased()) }) {
            return Int(match.productId)
        }
        throw PriceError.notFound
    }

    private func get(_ url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw PriceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw PriceError.badResponse(-1) }
        guard http.statusCode == 200 else { throw PriceError.badResponse(http.statusCode) }
        return data
    }
}
