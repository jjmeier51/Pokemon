import Foundation
import Observation

/// The immutable card list bundled with the app (Resources/cards.json).
@Observable
final class CardCatalog {
    struct File: Codable {
        let setName: String
        let setCode: String
        let releaseDate: String
        let source: String?
        let cards: [Card]
    }

    let setName: String
    let setCode: String
    let releaseDate: Date?
    let cards: [Card]
    private let byID: [String: Card]

    init(file: File) {
        setName = file.setName
        setCode = file.setCode
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        releaseDate = formatter.date(from: file.releaseDate)
        cards = file.cards.sorted { $0.sortIndex < $1.sortIndex }
        byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    }

    static func load(bundle: Bundle = .main) -> CardCatalog {
        guard let url = bundle.url(forResource: "cards", withExtension: "json")
                ?? bundle.url(forResource: "cards", withExtension: "json", subdirectory: "Resources") else {
            assertionFailure("cards.json is missing from the app bundle")
            return CardCatalog(file: File(setName: "30th Celebration", setCode: "30C", releaseDate: "2026-09-16", source: nil, cards: []))
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(File.self, from: data)
            return CardCatalog(file: file)
        } catch {
            assertionFailure("Failed to decode cards.json: \(error)")
            return CardCatalog(file: File(setName: "30th Celebration", setCode: "30C", releaseDate: "2026-09-16", source: nil, cards: []))
        }
    }

    func card(id: String) -> Card? { byID[id] }

    func cards(in section: CardSection) -> [Card] { cards.filter { $0.section == section } }

    func cards(of rarity: Rarity) -> [Card] { cards.filter { $0.rarity == rarity } }

    /// Rarities that actually occur in the catalog, rarest first.
    var rarities: [Rarity] {
        Array(Set(cards.map(\.rarity))).sorted { $0.rank > $1.rank }
    }
}
