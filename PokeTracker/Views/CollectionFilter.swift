import Foundation

enum CollectedFilter: String, CaseIterable, Identifiable {
    case all, collected, missing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .collected: return "Collected"
        case .missing: return "Missing"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case number, name, rarity, price, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .number: return "Card number"
        case .name: return "Name"
        case .rarity: return "Rarity"
        case .price: return "Market price"
        case .recent: return "Recently collected"
        }
    }
    var systemImage: String {
        switch self {
        case .number: return "number"
        case .name: return "textformat"
        case .rarity: return "sparkles"
        case .price: return "dollarsign.circle"
        case .recent: return "clock"
        }
    }
}

/// Everything that narrows and orders the grid.
struct CollectionFilter: Equatable {
    var search = ""
    var section: CardSection? = nil
    var collected: CollectedFilter = .all
    var rarities: Set<Rarity> = []
    var sort: SortOption = .number
    var ascending = true

    var isFiltering: Bool { collected != .all || !rarities.isEmpty }

    var activeCount: Int { (collected == .all ? 0 : 1) + (rarities.isEmpty ? 0 : 1) }

    @MainActor
    func apply(to cards: [Card], collection: CollectionStore, prices: PriceCenter) -> [Card] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let terms = query.split(separator: " ").map(String.init)

        var result = cards.filter { card in
            if let section, card.section != section { return false }
            if !rarities.isEmpty, !rarities.contains(card.rarity) { return false }
            switch collected {
            case .all: break
            case .collected: if !collection.isCollected(card) { return false }
            case .missing: if collection.isCollected(card) { return false }
            }
            if !terms.isEmpty {
                let haystack = card.searchableText
                for term in terms where !haystack.contains(term) { return false }
            }
            return true
        }

        result.sort { a, b in
            let order: Bool
            switch sort {
            case .number:
                order = a.sortIndex < b.sortIndex
            case .name:
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                order = cmp == .orderedSame ? a.sortIndex < b.sortIndex : cmp == .orderedAscending
            case .rarity:
                order = a.rarity.rank == b.rarity.rank ? a.sortIndex < b.sortIndex : a.rarity.rank > b.rarity.rank
            case .price:
                let pa = prices.value(of: a) ?? -1
                let pb = prices.value(of: b) ?? -1
                order = pa == pb ? a.sortIndex < b.sortIndex : pa > pb
            case .recent:
                let da = collection.entry(for: a)?.collectedAt ?? .distantPast
                let db = collection.entry(for: b)?.collectedAt ?? .distantPast
                order = da == db ? a.sortIndex < b.sortIndex : da > db
            }
            return ascending ? order : !order
        }
        return result
    }
}
