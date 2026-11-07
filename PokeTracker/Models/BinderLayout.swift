import Foundation

/// How the binder pages are laid out.
struct BinderOptions: Hashable {
    /// Add pages for cards that aren't in the ETB booklet (RGB Mew, promos) after the booklet pages.
    var includeExtras = true
    /// Start each booklet section (set, Classic Collection, extras) on a fresh page.
    var sectionsStartNewPage = true
}

/// One 9-pocket binder page. Slots read left→right, top→bottom; nil is an empty pocket.
struct BinderPage: Identifiable, Hashable {
    let index: Int              // 0-based
    let title: String           // section shown in the header
    let slots: [Card?]          // always 9

    var id: Int { index }
    var number: Int { index + 1 }
    var cards: [Card] { slots.compactMap { $0 } }
}

/// Builds binder pages in the ETB booklet order (the official card list order the catalogs carry as sortIndex).
enum BinderLayout {
    static let slotsPerPage = 9
    static let columns = 3

    struct Position: Hashable {
        let page: Int   // 1-based
        let slot: Int   // 1-based, 1 = top-left, 9 = bottom-right
        var row: Int { (slot - 1) / columns + 1 }
        var column: Int { (slot - 1) % columns + 1 }
    }

    /// Booklet sections in order. The numbered set (001–158 or 001–025) runs straight through,
    /// then the Classic Collection; RGB Mew and promos are extras the booklet doesn't list.
    static func groups(for set: CardSet, options: BinderOptions) -> [(title: String, cards: [Card])] {
        var groups: [(title: String, cards: [Card])] = []
        let numbered = set.cards.filter { $0.section == .main || $0.section == .secret }
        if !numbered.isEmpty { groups.append(("\(set.shortName)", numbered)) }
        let classic = set.cards(in: .classic)
        if !classic.isEmpty { groups.append(("Classic Collection", classic)) }
        if options.includeExtras {
            let rgb = set.cards(in: .rgb)
            if !rgb.isEmpty { groups.append(("RGB Mew", rgb)) }
            let promos = set.cards(in: .promo)
            if !promos.isEmpty { groups.append(("Promos", promos)) }
        }
        if !options.sectionsStartNewPage {
            return [("\(set.shortName) binder", groups.flatMap(\.cards))]
        }
        return groups
    }

    static func pages(for set: CardSet, options: BinderOptions) -> [BinderPage] {
        var pages: [BinderPage] = []
        for group in groups(for: set, options: options) {
            for chunk in group.cards.chunked(into: slotsPerPage) {
                var slots: [Card?] = chunk.map { Optional($0) }
                while slots.count < slotsPerPage { slots.append(nil) }
                pages.append(BinderPage(index: pages.count, title: group.title, slots: slots))
            }
        }
        return pages
    }

    static func position(of card: Card, in pages: [BinderPage]) -> Position? {
        for page in pages {
            if let slot = page.slots.firstIndex(where: { $0?.id == card.id }) {
                return Position(page: page.number, slot: slot + 1)
            }
        }
        return nil
    }

    static func position(of card: Card, in set: CardSet, options: BinderOptions) -> Position? {
        position(of: card, in: pages(for: set, options: options))
    }
}
