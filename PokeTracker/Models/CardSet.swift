import Foundation

/// A tracked expansion: its cards plus the branding used to present it.
struct CardSet: Identifiable, Hashable {
    let id: String              // set code, e.g. "30C" or "CEL"
    let name: String
    let shortName: String
    let tagline: String
    let releaseDate: Date?
    let logoAsset: String
    let markAsset: String
    let theme: AppTheme.ID
    let cards: [Card]

    static func == (lhs: CardSet, rhs: CardSet) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var sections: [CardSection] {
        CardSection.allCases.filter { section in cards.contains { $0.section == section } }
    }

    /// Rarities that occur in this set, rarest first.
    var rarities: [Rarity] {
        Array(Set(cards.map(\.rarity))).sorted { $0.rank > $1.rank }
    }

    func cards(in section: CardSection) -> [Card] { cards.filter { $0.section == section } }
    func cards(of rarity: Rarity) -> [Card] { cards.filter { $0.rarity == rarity } }

    /// Branding for the sets the app ships with, keyed by set code.
    struct Branding {
        let shortName: String
        let tagline: String
        let logoAsset: String
        let markAsset: String
        let theme: AppTheme.ID
        let resource: String
    }

    static let shipped: [String: Branding] = [
        "30C": Branding(shortName: "30th Celebration", tagline: "English master set · Sept 16, 2026", logoAsset: "Celebration30Logo", markAsset: "Pikachu30", theme: .celebration30, resource: "set-30th"),
        "CEL": Branding(shortName: "Celebrations", tagline: "25th anniversary · Oct 8, 2021", logoAsset: "CelebrationsLogo", markAsset: "Pikachu25", theme: .celebrations25, resource: "set-celebrations")
    ]

    /// Display order on the set switcher.
    static let order = ["30C", "CEL"]
}
