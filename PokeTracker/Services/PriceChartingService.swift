import Foundation

/// A single completed sale PriceCharting lists for a card.
struct GradedSale: Codable, Hashable, Identifiable {
    let date: Date
    let title: String
    let price: Double
    let company: GradingCompany?
    let grade: Double?
    let source: String?

    var id: String { "\(date.timeIntervalSince1970)-\(title)-\(price)" }
    var isRaw: Bool { company == nil }
}

enum GradedSource: String, Codable {
    case pricecharting
    case cardladder

    var title: String {
        switch self {
        case .pricecharting: return "PriceCharting"
        case .cardladder: return "Card Ladder"
        }
    }
}

/// Everything a source knows about one card's graded values: a price guide by grade and recent sales.
struct GradedQuote: Codable, Hashable {
    /// Market value per guide row, keyed by label. PriceCharting rows: "Ungraded", "Grade 9", "PSA 10",
    /// "CGC 10", "BGS 10", "TAG 10", … Card Ladder rows are company-specific for every grade: "PSA 9", "CGC 9.5", …
    var guide: [String: Double]
    var sales: [GradedSale]
    var pageURL: URL
    var fetchedAt: Date
    var source: GradedSource? = .pricecharting
    /// Card Ladder's "last sold" date per guide label, when it doesn't expose the sale price itself.
    var lastSold: [String: Date]? = nil

    var ungraded: Double? { guide["Ungraded"] }

    /// Guide value for a company + grade. Company-specific rows win; PriceCharting's
    /// company-agnostic "Grade N" rows cover grades below 10.
    func guideValue(company: GradingCompany, grade: Double) -> (label: String, value: Double)? {
        let g = Grade.label(grade)
        var candidates = ["\(company.title) \(g)"]
        if grade == 10 {
            switch company {
            case .psa: candidates += ["PSA GEM MT 10"]
            case .cgc: candidates += ["CGC 10 Pristine", "CGC Pristine 10"]
            case .bgs: candidates += ["BGS 10 Black", "BGS Black Label 10"]
            case .tag: break
            }
        } else {
            candidates.append("Grade \(g)")
        }
        for label in candidates {
            if let value = guide[label] { return (label, value) }
        }
        return nil
    }

    /// The value to count a slab at: the guide row for its grade, else its most recent matching sale.
    func value(company: GradingCompany, grade: Double) -> (label: String, value: Double)? {
        if let guide = guideValue(company: company, grade: grade) { return guide }
        if let sale = latestSale(company: company, grade: grade) { return ("last \(company.title) \(Grade.label(grade)) sale", sale.price) }
        return nil
    }

    /// Most recent completed sale matching the company + grade (or raw when company is nil).
    func latestSale(company: GradingCompany?, grade: Double?) -> GradedSale? {
        sales
            .filter { sale in
                if let company {
                    return sale.company == company && (grade == nil || sale.grade == grade)
                }
                return sale.isRaw
            }
            .max { $0.date < $1.date }
    }

    func recentSales(company: GradingCompany?, grade: Double?, limit: Int = 5) -> [GradedSale] {
        Array(sales
            .filter { sale in
                if let company { return sale.company == company && (grade == nil || sale.grade == grade) }
                return sale.isRaw
            }
            .sorted { $0.date > $1.date }
            .prefix(limit))
    }
}

/// Scrapes PriceCharting's public card pages for graded market values and completed sales.
struct PriceChartingService: Sendable {
    private let session: URLSession
    private static let base = URL(string: "https://www.pricecharting.com")!

    init(session: URLSession = PriceChartingService.makeSession()) {
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }

    // MARK: - Public API

    func quote(for card: Card) async throws -> GradedQuote {
        let path: String
        if let known = card.pricechartingPath, !known.isEmpty {
            path = known
        } else {
            path = try await resolvePath(for: card)
        }
        let url = Self.base.appendingPathComponent(path)
        var html: String
        do {
            (html, _) = try await fetch(url)
        } catch PriceError.network(let detail) {
            // Pages are large; give a flaky connection one more chance before giving up.
            try await Task.sleep(nanoseconds: 1_500_000_000)
            do { (html, _) = try await fetch(url) } catch { throw PriceError.network(detail) }
        }
        let guide = Self.parseGuide(html)
        let sales = Self.parseSales(html)
        guard !guide.isEmpty || !sales.isEmpty else { throw PriceError.decoding("PriceCharting page") }
        return GradedQuote(guide: guide, sales: sales, pageURL: url, fetchedAt: Date(), source: .pricecharting)
    }

    // MARK: - Resolving a card to a PriceCharting page

    func resolvePath(for card: Card) async throws -> String {
        var components = URLComponents(url: Self.base.appendingPathComponent("search-products"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: card.marketplaceQuery), URLQueryItem(name: "type", value: "prices")]
        let (html, finalURL) = try await fetch(components.url!)
        // A single match serves the product page directly; its canonical link names the product path.
        if finalURL.path.hasPrefix("/game/") { return finalURL.path }
        if let canonical = Self.regexMatches(#"<link rel="canonical" href="([^"]+)""#, in: html).first,
           let url = URL(string: canonical[1]), url.path.hasPrefix("/game/") {
            return url.path
        }
        let rows = Self.regexMatches(#"<tr id="product-(\d+)"[^>]*>[\s\S]*?<td class="title">\s*<a href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>[\s\S]*?<a href="/console/[^"]+">\s*([^<]+?)\s*</a>"#, in: html)
        let number = card.number.lowercased()
        let setWord = card.setSearchName.lowercased().contains("celebrations") ? "celebrations" : "30th"
        func score(_ row: [String]) -> Int {
            let title = row[3].lowercased(), set = row[4].lowercased()
            var score = 0
            if set.contains(setWord) { score += 10 }
            if card.section == .classic, set.contains("classic") { score += 5 }
            if card.section == .promo, set.contains("promo") { score += 5 }
            let trimmed = number.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if title.contains("#\(trimmed)") || title.contains(number) { score += 6 }
            if let first = card.name.lowercased().split(separator: " ").first, title.contains(first) { score += 3 }
            return score
        }
        // Only accept a result that names this exact card number in the expected set; a wrong
        // page would silently show another card's prices.
        let trimmedNumber = number.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
        let acceptable = rows.filter { row in
            let title = row[3].lowercased(), set = row[4].lowercased()
            let numberOK = title.contains("#\(trimmedNumber)") || title.contains("#\(number)")
            let setOK = set.contains(setWord) || (card.section == .promo && set.contains("promo"))
            let nameOK = card.name.lowercased().split(separator: " ").first.map { title.contains($0) } ?? true
            return numberOK && setOK && nameOK && !set.contains("japanese")
        }
        guard let best = acceptable.max(by: { score($0) < score($1) }), let url = URL(string: best[2]) else { throw PriceError.notFound }
        return url.path
    }

    // MARK: - Parsing

    static func parseGuide(_ html: String) -> [String: Double] {
        var guide: [String: Double] = [:]
        guard let start = html.range(of: "id=\"full-prices\"") else { return guide }
        let segment = String(html[start.upperBound...].prefix(12_000))
        // Rows look like: <tr><td>Grade 9</td><td class="price js-price">$186.25</td></tr>
        for row in regexMatches(#"<tr>\s*<td[^>]*>\s*([^<]+?)\s*</td>\s*<td[^>]*class="[^"]*js-price[^"]*"[^>]*>\s*(?:<span[^>]*>)?\s*([^<]+?)\s*<"#, in: segment) {
            if let value = parsePrice(row[2]) { guide[row[1]] = value }
        }
        return guide
    }

    static func parseSales(_ html: String) -> [GradedSale] {
        var sales: [GradedSale] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Chicago")

        // The page is close to a megabyte, so work row by row instead of running one
        // regex over the whole document (which backtracks badly).
        let chunks = html.components(separatedBy: "<tr id=\"").dropFirst()
        for chunk in chunks {
            let row: Substring
            if let close = chunk.range(of: "</tr>") { row = chunk[..<close.lowerBound] } else { row = chunk.prefix(3000) }
            let text = String(row)
            guard let source = regexMatches(#"^([a-z]+)-"#, in: text).first?[1],
                  let dateString = regexMatches(#"<td class="date">\s*([0-9-]+)\s*</td>"#, in: text).first?[1],
                  let date = formatter.date(from: dateString),
                  let titleStart = text.range(of: "<td class=\"title\">"),
                  let title = regexMatches(#"<a[^>]*>\s*([^<]+?)\s*</a>"#, in: String(text[titleStart.upperBound...])).first?[1],
                  let priceText = regexMatches(#"<td class="numeric">\s*<span class="js-price"[^>]*>\s*([^<]+?)\s*</span>"#, in: text).first?[1],
                  let price = parsePrice(priceText) else { continue }
            let cleanTitle = decodeEntities(title)
            let (company, grade) = classify(cleanTitle)
            sales.append(GradedSale(date: date, title: cleanTitle, price: price, company: company, grade: grade, source: source))
        }
        // De-duplicate identical rows that appear in more than one tab.
        var seen = Set<String>()
        return sales.filter { seen.insert($0.id).inserted }
    }

    /// Reads "PSA 10", "CGC 9.5", "BGS 9", "TAG 10", "Beckett 9.5" out of a listing title.
    static func classify(_ title: String) -> (GradingCompany?, Double?) {
        let upper = title.uppercased()
        let patterns: [(GradingCompany, String)] = [
            (.psa, #"\bPSA\s*(?:GEM\s*(?:MT|MINT)\s*)?(10|9\.5|9|8\.5|8|7\.5|7|6\.5|6|5|4|3|2|1)(?!\d)"#),
            (.cgc, #"\bCGC\s*(?:PRISTINE\s*|GEM\s*MINT\s*|PERFECT\s*)?(10|9\.5|9|8\.5|8|7\.5|7|6\.5|6|5|4|3|2|1)(?!\d)"#),
            (.bgs, #"\b(?:BGS|BECKETT)\s*(?:BLACK\s*LABEL\s*|PRISTINE\s*)?(10|9\.5|9|8\.5|8|7\.5|7|6\.5|6|5|4|3|2|1)(?!\d)"#),
            (.tag, #"\bTAG\s*(10|9\.5|9|8\.5|8|7\.5|7|6\.5|6|5|4|3|2|1)(?!\d)"#)
        ]
        for (company, pattern) in patterns {
            if let match = regexMatches(pattern, in: upper).first, let grade = Double(match[1]) {
                return (company, grade)
            }
        }
        return (nil, nil)
    }

    // MARK: - Helpers

    private func fetch(_ url: URL) async throws -> (String, URL) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw PriceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw PriceError.badResponse(-1) }
        guard http.statusCode == 200 else { throw PriceError.badResponse(http.statusCode) }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw PriceError.decoding("html") }
        return (html, http.url ?? url)
    }

    static func parsePrice(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// Returns each match as [whole, group1, group2, ...].
    static func regexMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }
}
