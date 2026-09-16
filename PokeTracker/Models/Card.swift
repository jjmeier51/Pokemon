import Foundation

/// Which part of the 30th Celebration checklist a card belongs to.
enum CardSection: String, Codable, CaseIterable, Identifiable {
    case main
    case secret
    case rgb
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "Main Set"
        case .secret: return "Secret Rares"
        case .rgb: return "RGB Mew"
        case .classic: return "Classic Collection"
        }
    }

    var shortTitle: String {
        switch self {
        case .main: return "Main"
        case .secret: return "Secrets"
        case .rgb: return "RGB"
        case .classic: return "Classic"
        }
    }

    var subtitle: String {
        switch self {
        case .main: return "001–128"
        case .secret: return "129–158"
        case .rgb: return "R · G · B"
        case .classic: return "30 reprints"
        }
    }

    var systemImage: String {
        switch self {
        case .main: return "square.grid.3x3.fill"
        case .secret: return "sparkles"
        case .rgb: return "circle.hexagongrid.fill"
        case .classic: return "clock.arrow.circlepath"
        }
    }
}

/// Rarity tiers as printed on the official checklist, plus the unlisted RGB Mew tier.
enum Rarity: String, Codable, CaseIterable, Identifiable {
    case common
    case rare
    case doubleRare
    case pikachuRare
    case illustrationRare
    case specialIllustrationRare
    case futuristicRare
    case rgbSecret
    case classicCollection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .doubleRare: return "Double Rare"
        case .pikachuRare: return "Pikachu Rare"
        case .illustrationRare: return "Illustration Rare"
        case .specialIllustrationRare: return "Special Illustration Rare"
        case .futuristicRare: return "Futuristic Rare"
        case .rgbSecret: return "RGB Secret"
        case .classicCollection: return "Classic Collection"
        }
    }

    var shortTitle: String {
        switch self {
        case .common: return "C"
        case .rare: return "R"
        case .doubleRare: return "RR"
        case .pikachuRare: return "PR"
        case .illustrationRare: return "IR"
        case .specialIllustrationRare: return "SIR"
        case .futuristicRare: return "FR"
        case .rgbSecret: return "RGB"
        case .classicCollection: return "CC"
        }
    }

    /// The glyph printed next to the card on the official checklist.
    var symbol: String {
        switch self {
        case .common: return "●"
        case .rare: return "★"
        case .doubleRare: return "★★"
        case .pikachuRare: return "⚡︎"
        case .illustrationRare: return "★"
        case .specialIllustrationRare: return "★★"
        case .futuristicRare: return "★"
        case .rgbSecret: return "◆"
        case .classicCollection: return "★C"
        }
    }

    /// Higher is rarer. Used for sorting.
    var rank: Int {
        switch self {
        case .common: return 1
        case .rare: return 2
        case .doubleRare: return 3
        case .pikachuRare: return 4
        case .classicCollection: return 5
        case .illustrationRare: return 6
        case .specialIllustrationRare: return 7
        case .futuristicRare: return 8
        case .rgbSecret: return 9
        }
    }
}

enum EnergyType: String, Codable, CaseIterable, Identifiable {
    case grass, fire, water, lightning, psychic, fighting, darkness, metal, dragon, colorless, fairy

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum CardKind: String, Codable {
    case pokemon
    case trainer
    case energy
}

struct ClassicOrigin: Codable, Hashable {
    let setName: String
    let number: String
    let year: Int
}

struct Card: Codable, Identifiable, Hashable {
    let id: String
    let sortIndex: Int
    let name: String
    let number: String
    let displayNumber: String
    let section: CardSection
    let rarity: Rarity
    let energyType: EnergyType?
    let cardKind: CardKind?
    let stage: String?
    let hp: Int?
    let artist: String?
    let flavorText: String?
    let ability: String?
    let attacks: [String]?
    let weakness: String?
    let resistance: String?
    let retreatCost: String?
    let classicOrigin: ClassicOrigin?
    let tcgplayerProductId: Int?
    let tcgplayerURL: URL?
    let imageName: String
    let remoteImageURL: URL?
    let notes: String?

    static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Text used by the search bar.
    var searchableText: String {
        var parts = [name, number, displayNumber, rarity.title, rarity.shortTitle, section.title]
        if let artist { parts.append(artist) }
        if let energyType { parts.append(energyType.title) }
        if let classicOrigin { parts.append(classicOrigin.setName) }
        if let stage { parts.append(stage) }
        return parts.joined(separator: " ").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var subtitle: String {
        if let classicOrigin {
            return "\(classicOrigin.setName) · \(classicOrigin.year)"
        }
        return rarity.title
    }

    /// Search query used when looking a card up on a marketplace.
    var marketplaceQuery: String {
        switch section {
        case .classic:
            return "\(name) \(displayNumber) 30th Celebration Classic Collection"
        case .rgb:
            return "Mew \(displayNumber) 30th Celebration"
        default:
            return "\(name) \(displayNumber) 30th Celebration"
        }
    }
}
