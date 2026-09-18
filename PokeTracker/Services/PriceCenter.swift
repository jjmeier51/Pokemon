import Foundation
import Observation

/// Coordinates price lookups from every source, caches results on disk, and exposes loading state to views.
@MainActor
@Observable
final class PriceCenter {
    private(set) var prices: [String: CardPrices] = [:]
    private(set) var loading: Set<String> = []
    private(set) var errors: [String: [PriceSource: String]] = [:]
    private(set) var bulkProgress: (done: Int, total: Int)?
    private(set) var graded: [String: GradedQuote] = [:]
    private(set) var gradedLoading: Set<String> = []
    private(set) var gradedErrors: [String: String] = [:]
    private(set) var gradedBulkProgress: (done: Int, total: Int)?

    /// Quotes older than this are refreshed automatically when a card is viewed.
    var staleInterval: TimeInterval = 6 * 60 * 60

    private let fileURL: URL
    private let tcgplayer = TCGPlayerService()
    private let pricecharting = PriceChartingService()
    private var gradedTasks: [String: Task<Void, Never>] = [:]
    private let gradedFileURL: URL
    private var tasks: [String: Task<Void, Never>] = [:]

    init(fileURL: URL? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? caches.appendingPathComponent("prices.json")
        self.gradedFileURL = caches.appendingPathComponent("graded-prices.json")
        load()
    }

    // MARK: - Queries

    func prices(for card: Card) -> CardPrices? { prices[card.id] }

    func isLoading(_ card: Card) -> Bool { loading.contains(card.id) }

    func error(for card: Card, source: PriceSource) -> String? { errors[card.id]?[source] }

    func isStale(_ card: Card) -> Bool {
        guard let entry = prices[card.id] else { return true }
        return Date().timeIntervalSince(entry.updatedAt) > staleInterval
    }

    func value(of card: Card) -> Double? { prices[card.id]?.bestValue }

    func totalValue(of cards: [Card]) -> Double {
        cards.reduce(0) { $0 + (value(of: $1) ?? 0) }
    }

    var lastUpdated: Date? { prices.values.map(\.updatedAt).max() }

    // MARK: - Graded (PriceCharting)

    func gradedQuote(for card: Card) -> GradedQuote? { graded[card.id] }

    func isGradedLoading(_ card: Card) -> Bool { gradedLoading.contains(card.id) }

    func gradedError(for card: Card) -> String? { gradedErrors[card.id] }

    /// The value to count a collected card at: the grade's guide price when it is slabbed, else the raw market price.
    func value(of card: Card, grading: Grading?) -> Double? {
        if let grading, let quote = graded[card.id], let guide = quote.guideValue(company: grading.company, grade: grading.grade) {
            return guide.value
        }
        return value(of: card)
    }

    func refreshGradedIfStale(_ card: Card, maxAge: TimeInterval = 12 * 60 * 60) {
        if let quote = graded[card.id], Date().timeIntervalSince(quote.fetchedAt) < maxAge { return }
        refreshGraded(card)
    }

    func refreshGraded(_ card: Card) {
        if gradedTasks[card.id] != nil { return }
        gradedLoading.insert(card.id)
        let service = pricecharting
        gradedTasks[card.id] = Task { [weak self] in
            let result: Result<GradedQuote, Error> = await Self.captureGraded { try await service.quote(for: card) }
            guard let self else { return }
            switch result {
            case .success(let quote):
                self.graded[card.id] = quote
                self.gradedErrors[card.id] = nil
                self.saveGraded()
            case .failure(let error):
                self.gradedErrors[card.id] = error.localizedDescription
            }
            self.gradedLoading.remove(card.id)
            self.gradedTasks[card.id] = nil
        }
    }

    /// Fetches PriceCharting pages for many cards with limited concurrency (each page is large).
    func refreshGradedAll(_ cards: [Card], onlyStale: Bool = true, maxAge: TimeInterval = 12 * 60 * 60) async {
        let targets = cards.filter { card in
            guard onlyStale, let quote = graded[card.id] else { return true }
            return Date().timeIntervalSince(quote.fetchedAt) > maxAge
        }
        guard !targets.isEmpty else { return }
        gradedBulkProgress = (0, targets.count)
        let service = pricecharting
        var done = 0
        for chunk in targets.chunked(into: 3) {
            await withTaskGroup(of: (Card, Result<GradedQuote, Error>).self) { group in
                for card in chunk {
                    group.addTask { (card, await Self.captureGraded { try await service.quote(for: card) }) }
                }
                for await (card, result) in group {
                    switch result {
                    case .success(let quote):
                        graded[card.id] = quote
                        gradedErrors[card.id] = nil
                    case .failure(let error):
                        gradedErrors[card.id] = error.localizedDescription
                    }
                    done += 1
                    gradedBulkProgress = (done, targets.count)
                }
            }
        }
        saveGraded()
        gradedBulkProgress = nil
    }

    /// Whether a collected, graded card is currently being counted at its grade's value.
    func isValuedAtGrade(_ card: Card, grading: Grading?) -> Bool {
        guard let grading, let quote = graded[card.id] else { return false }
        return quote.guideValue(company: grading.company, grade: grading.grade) != nil
    }

    private static func captureGraded(_ work: @escaping @Sendable () async throws -> GradedQuote) async -> Result<GradedQuote, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func saveGraded() {
        let snapshot = graded
        let url = gradedFileURL
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
    }

    // MARK: - Refreshing

    func refreshIfStale(_ card: Card, settings: AppSettings) {
        guard isStale(card) else { return }
        refresh(card, settings: settings)
    }

    func refresh(_ card: Card, settings: AppSettings, sources: Set<PriceSource> = Set(PriceSource.allCases)) {
        if tasks[card.id] != nil { return }
        loading.insert(card.id)
        let cardLadder = settings.hasCardLadderKey
            ? CardLadderService(baseURL: settings.cardLadderBaseURL, apiKey: settings.cardLadderAPIKey)
            : nil
        let tcg = tcgplayer
        tasks[card.id] = Task { [weak self] in
            async let tcgResult: Result<PriceQuote, Error> = Self.capture { try await tcg.quote(for: card) }
            async let clResult: Result<PriceQuote, Error>? = {
                guard sources.contains(.cardladder), let cardLadder else { return nil }
                return await Self.capture { try await cardLadder.quote(for: card) }
            }()
            let tcgOutcome = sources.contains(.tcgplayer) ? await tcgResult : nil
            let clOutcome = await clResult
            guard let self else { return }
            self.apply(card: card, tcgplayer: tcgOutcome, cardladder: clOutcome, hasCardLadderKey: cardLadder != nil)
            self.loading.remove(card.id)
            self.tasks[card.id] = nil
        }
    }

    /// Refreshes many cards with limited concurrency. Used by the Stats screen and Settings.
    func refreshAll(_ cards: [Card], settings: AppSettings, onlyStale: Bool = true) async {
        let targets = onlyStale ? cards.filter { isStale($0) } : cards
        guard !targets.isEmpty else { return }
        bulkProgress = (0, targets.count)
        let cardLadder = settings.hasCardLadderKey
            ? CardLadderService(baseURL: settings.cardLadderBaseURL, apiKey: settings.cardLadderAPIKey)
            : nil
        let tcg = tcgplayer
        var done = 0
        for chunk in targets.chunked(into: 4) {
            await withTaskGroup(of: (Card, Result<PriceQuote, Error>, Result<PriceQuote, Error>?).self) { group in
                for card in chunk {
                    group.addTask {
                        let t = await Self.capture { try await tcg.quote(for: card) }
                        var c: Result<PriceQuote, Error>? = nil
                        if let cardLadder { c = await Self.capture { try await cardLadder.quote(for: card) } }
                        return (card, t, c)
                    }
                }
                for await (card, t, c) in group {
                    apply(card: card, tcgplayer: t, cardladder: c, hasCardLadderKey: cardLadder != nil)
                    done += 1
                    bulkProgress = (done, targets.count)
                }
            }
        }
        bulkProgress = nil
    }

    func clearCache() {
        prices = [:]
        errors = [:]
        graded = [:]
        gradedErrors = [:]
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: gradedFileURL)
    }

    // MARK: - Internals

    private static func capture(_ work: @escaping @Sendable () async throws -> PriceQuote) async -> Result<PriceQuote, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func apply(card: Card, tcgplayer: Result<PriceQuote, Error>?, cardladder: Result<PriceQuote, Error>?, hasCardLadderKey: Bool) {
        var entry = prices[card.id] ?? CardPrices(updatedAt: Date())
        var cardErrors = errors[card.id] ?? [:]

        switch tcgplayer {
        case .success(let quote)?:
            entry.tcgplayer = quote
            cardErrors[.tcgplayer] = nil
        case .failure(let error)?:
            cardErrors[.tcgplayer] = error.localizedDescription
        case nil:
            break
        }

        switch cardladder {
        case .success(let quote)?:
            entry.cardladder = quote
            cardErrors[.cardladder] = nil
        case .failure(let error)?:
            cardErrors[.cardladder] = error.localizedDescription
        case nil:
            cardErrors[.cardladder] = hasCardLadderKey ? nil : PriceError.missingAPIKey.localizedDescription
        }

        entry.updatedAt = Date()
        prices[card.id] = entry
        errors[card.id] = cardErrors.isEmpty ? nil : cardErrors
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([String: CardPrices].self, from: data) {
            prices = decoded
        }
        if let gradedData = try? Data(contentsOf: gradedFileURL),
           let decodedGraded = try? decoder.decode([String: GradedQuote].self, from: gradedData) {
            graded = decodedGraded
        }
    }

    private var saveTask: Task<Void, Never>?

    private func save() {
        saveTask?.cancel()
        let snapshot = prices
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
