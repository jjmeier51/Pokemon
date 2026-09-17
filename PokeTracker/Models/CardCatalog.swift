import Foundation
import Observation

/// The immutable card lists bundled with the app (Resources/set-*.json).
@Observable
final class CardCatalog {
    struct File: Codable {
        let setName: String
        let setCode: String
        let releaseDate: String
        let source: String?
        let cards: [Card]
    }

    let sets: [CardSet]
    private let byID: [String: Card]
    private let setByCardID: [String: String]

    init(sets: [CardSet]) {
        self.sets = sets
        byID = Dictionary(uniqueKeysWithValues: sets.flatMap(\.cards).map { ($0.id, $0) })
        setByCardID = Dictionary(uniqueKeysWithValues: sets.flatMap { set in set.cards.map { ($0.id, set.id) } })
    }

    static func load(bundle: Bundle = .main) -> CardCatalog {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var sets: [CardSet] = []
        for code in CardSet.order {
            guard let branding = CardSet.shipped[code] else { continue }
            guard let url = bundle.url(forResource: branding.resource, withExtension: "json")
                    ?? bundle.url(forResource: branding.resource, withExtension: "json", subdirectory: "Resources") else {
                assertionFailure("\(branding.resource).json is missing from the app bundle")
                continue
            }
            do {
                let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
                sets.append(CardSet(id: file.setCode, name: file.setName, shortName: branding.shortName, tagline: branding.tagline,
                                    releaseDate: formatter.date(from: file.releaseDate), logoAsset: branding.logoAsset, markAsset: branding.markAsset,
                                    theme: branding.theme, cards: file.cards.sorted { $0.sortIndex < $1.sortIndex }))
            } catch {
                assertionFailure("Failed to decode \(branding.resource).json: \(error)")
            }
        }
        return CardCatalog(sets: sets)
    }

    var allCards: [Card] { sets.flatMap(\.cards) }

    func card(id: String) -> Card? { byID[id] }

    func set(id: String) -> CardSet? { sets.first { $0.id == id } }

    func set(for card: Card) -> CardSet? { setByCardID[card.id].flatMap { set(id: $0) } }

    /// The set with this id, falling back to the first shipped set.
    func selectedSet(id: String) -> CardSet {
        set(id: id) ?? sets[0]
    }
}
