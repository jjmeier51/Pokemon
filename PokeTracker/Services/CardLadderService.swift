import Foundation

/// Card Ladder does not publish an official API. This client talks to the Parse.bot
/// "Card Ladder API" wrapper (https://parse.bot), which exposes Card Ladder's search,
/// CL Value and sales data as JSON behind an `X-API-Key` header. The base URL and key
/// are configurable in Settings so any compatible bridge can be used instead.
struct CardLadderService: Sendable {
    let baseURL: URL
    let apiKey: String
    private let session: URLSession

    init(baseURL: String, apiKey: String, session: URLSession = CardLadderService.makeSession()) {
        self.baseURL = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) ?? URL(string: AppSettings.defaultCardLadderBaseURL)!
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = ["Accept": "application/json", "User-Agent": "PokeTracker/1.0 (iOS)"]
        return URLSession(configuration: config)
    }

    // MARK: - Public API

    func quote(for card: Card) async throws -> PriceQuote {
        guard !apiKey.isEmpty else { throw PriceError.missingAPIKey }

        let hits = try await search(query: card.marketplaceQuery)
        guard let match = bestMatch(for: card, in: hits) else { throw PriceError.notFound }

        var quote = PriceQuote(source: .cardladder, fetchedAt: Date())
        quote.marketPrice = match.currentValue ?? match.marketValue
        quote.trailingSalesCount = match.numSales
        quote.listingURL = cardLadderWebURL(for: card, cardId: match.id)

        if let detail = try? await value(cardId: match.id) {
            quote.marketPrice = detail.clValue ?? quote.marketPrice
            quote.latestSaleAverage = detail.newestSalePrice
            quote.latestSaleDate = detail.newestSaleDate
            if let ninetyDay = detail.ninetyDayAverage { quote.note = "90-day avg \(ninetyDay.usd)" }
        }
        if let sales = try? await sales(cardId: match.id) {
            let sorted = sales.sorted { $0.date < $1.date }
            quote.history = sorted.map { PricePoint(date: $0.date, price: $0.price, quantitySold: $0.count) }
            if let latest = sorted.last {
                quote.latestSaleAverage = quote.latestSaleAverage ?? latest.price
                quote.latestSaleDate = quote.latestSaleDate ?? latest.date
                quote.latestSaleCount = latest.count
            }
        }
        if quote.marketPrice == nil, quote.latestSaleAverage == nil { throw PriceError.notFound }
        return quote
    }

    func cardLadderWebURL(for card: Card, cardId: String?) -> URL {
        if let cardId, !cardId.isEmpty, let url = URL(string: "https://app.cardladder.com/card/\(cardId)") { return url }
        var components = URLComponents(string: "https://app.cardladder.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: card.marketplaceQuery)]
        return components.url!
    }

    // MARK: - Matching

    struct SearchHit {
        let id: String
        let label: String
        let currentValue: Double?
        let marketValue: Double?
        let numSales: Int?
        let lastSoldDate: Date?
    }

    private func bestMatch(for card: Card, in hits: [SearchHit]) -> SearchHit? {
        let graded = ["psa", "bgs", "cgc", "sgc", "tag", "ace"]
        let number = card.displayNumber.lowercased()
        let name = card.name.lowercased()
        func score(_ hit: SearchHit) -> Int {
            let label = hit.label.lowercased()
            var score = 0
            if label.contains(number) { score += 40 }
            if label.contains(name) { score += 20 }
            if label.contains("30th") || label.contains("celebration") { score += 10 }
            if graded.contains(where: { label.contains($0 + " ") || label.hasSuffix($0) }) { score -= 15 } // prefer raw/ungraded
            if hit.currentValue != nil || hit.marketValue != nil { score += 5 }
            return score
        }
        return hits.filter { score($0) > 0 }.max { score($0) < score($1) }
    }

    // MARK: - Endpoints

    private func search(query: String) async throws -> [SearchHit] {
        let json = try await getJSON(path: "search_cards", query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "category", value: "Pokemon")
        ])
        let list = (json["cards"] as? [[String: Any]]) ?? (json["results"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
        return list.compactMap { item in
            guard let id = item.string("id") ?? item.string("card_id") else { return nil }
            return SearchHit(id: id,
                             label: item.string("label") ?? item.string("name") ?? item.string("title") ?? "",
                             currentValue: item.double("current_value") ?? item.double("cl_value"),
                             marketValue: item.double("market_value"),
                             numSales: item.int("num_sales"),
                             lastSoldDate: item.date("last_sold_date"))
        }
    }

    struct ValueDetail {
        let clValue: Double?
        let marketValue: Double?
        let newestSalePrice: Double?
        let newestSaleDate: Date?
        let ninetyDayAverage: Double?
    }

    private func value(cardId: String) async throws -> ValueDetail {
        let json = try await getJSON(path: "get_card_value", query: [URLQueryItem(name: "card_id", value: cardId)])
        let root = (json["value"] as? [String: Any]) ?? (json["data"] as? [String: Any]) ?? json
        let newest = root["newest_sale"] as? [String: Any]
        let periods = root["period_summaries"] as? [String: Any] ?? root["periods"] as? [String: Any]
        let ninety = (periods?["90d"] as? [String: Any])?.double("average") ?? (periods?["90"] as? [String: Any])?.double("average")
        return ValueDetail(clValue: root.double("cl_value") ?? root.double("current_value"),
                           marketValue: root.double("market_value"),
                           newestSalePrice: newest?.double("price") ?? root.double("newest_sale_price") ?? root.double("last_sale_price"),
                           newestSaleDate: newest?.date("date") ?? root.date("newest_sale_date") ?? root.date("last_sold_date"),
                           ninetyDayAverage: ninety)
    }

    struct DailySale {
        let date: Date
        let price: Double
        let count: Int
    }

    private func sales(cardId: String) async throws -> [DailySale] {
        let json = try await getJSON(path: "get_card_sales", query: [URLQueryItem(name: "card_id", value: cardId)])
        let list = (json["sales"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? (json["results"] as? [[String: Any]]) ?? []
        return list.compactMap { item in
            guard let date = item.date("date"), let price = item.double("price") ?? item.double("avg_price") else { return nil }
            return DailySale(date: date, price: price, count: item.int("count") ?? item.int("total_sales") ?? 1)
        }
    }

    private func getJSON(path: String, query: [URLQueryItem]) async throws -> [String: Any] {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PriceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw PriceError.badResponse(-1) }
        guard http.statusCode == 200 else { throw PriceError.badResponse(http.statusCode) }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { throw PriceError.decoding("not JSON") }
        if let dict = object as? [String: Any] { return dict }
        if let array = object as? [[String: Any]] { return ["data": array] }
        throw PriceError.decoding("unexpected shape")
    }
}

// MARK: - Lenient JSON helpers

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        if let s = self[key] as? String, !s.isEmpty { return s }
        if let n = self[key] as? NSNumber { return n.stringValue }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let d = self[key] as? Double { return d }
        if let n = self[key] as? NSNumber { return n.doubleValue }
        if let s = self[key] as? String { return Double(s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let i = self[key] as? Int { return i }
        if let n = self[key] as? NSNumber { return n.intValue }
        if let s = self[key] as? String { return Int(s) }
        return nil
    }

    func date(_ key: String) -> Date? {
        guard let raw = self[key] else { return nil }
        if let seconds = raw as? Double { return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds) }
        if let seconds = raw as? Int { return Date(timeIntervalSince1970: Double(seconds) > 10_000_000_000 ? Double(seconds) / 1000 : Double(seconds)) }
        guard let string = raw as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: string) { return d }
        let plain = DateFormatter()
        plain.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "MM/dd/yyyy"] {
            plain.dateFormat = format
            if let d = plain.date(from: string) { return d }
        }
        return nil
    }
}
