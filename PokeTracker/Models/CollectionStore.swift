import Foundation
import Observation

/// Persists which cards the user owns. Stored as JSON in the app's Documents folder.
@MainActor
@Observable
final class CollectionStore {
    struct Entry: Codable, Hashable {
        var quantity: Int
        var collectedAt: Date
        var favorite: Bool = false
        var note: String = ""
        /// Nil means the card is held raw (ungraded).
        var grading: Grading? = nil
    }

    struct Snapshot: Codable {
        var version: Int = 1
        var entries: [String: Entry]
        var exportedAt: Date = Date()
    }

    private(set) var entries: [String: Entry] = [:]
    private(set) var lastChangedID: String?

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? documents.appendingPathComponent("collection.json")
        load()
    }

    // MARK: - Queries

    func isCollected(_ id: String) -> Bool { (entries[id]?.quantity ?? 0) > 0 }

    func isCollected(_ card: Card) -> Bool { isCollected(card.id) }

    func quantity(of card: Card) -> Int { entries[card.id]?.quantity ?? 0 }

    func entry(for card: Card) -> Entry? { entries[card.id] }

    func collectedCount(in cards: [Card]) -> Int { cards.reduce(0) { $0 + (isCollected($1) ? 1 : 0) } }

    var collectedIDs: Set<String> { Set(entries.filter { $0.value.quantity > 0 }.keys) }

    // MARK: - Mutations

    func toggle(_ card: Card) {
        if isCollected(card) {
            entries[card.id] = nil
        } else {
            entries[card.id] = Entry(quantity: 1, collectedAt: Date())
        }
        lastChangedID = card.id
        scheduleSave()
    }

    func setCollected(_ card: Card, _ collected: Bool) {
        if collected != isCollected(card) { toggle(card) }
    }

    func setQuantity(_ card: Card, _ quantity: Int) {
        let q = max(0, quantity)
        if q == 0 {
            entries[card.id] = nil
        } else if var entry = entries[card.id] {
            entry.quantity = q
            entries[card.id] = entry
        } else {
            entries[card.id] = Entry(quantity: q, collectedAt: Date())
        }
        lastChangedID = card.id
        scheduleSave()
    }

    func setFavorite(_ card: Card, _ favorite: Bool) {
        guard var entry = entries[card.id] else { return }
        entry.favorite = favorite
        entries[card.id] = entry
        scheduleSave()
    }

    func setGrading(_ card: Card, _ grading: Grading?) {
        guard var entry = entries[card.id] else { return }
        entry.grading = grading
        entries[card.id] = entry
        scheduleSave()
    }

    func setNote(_ card: Card, _ note: String) {
        guard var entry = entries[card.id] else { return }
        entry.note = note
        entries[card.id] = entry
        scheduleSave()
    }

    func markAll(_ cards: [Card], collected: Bool) {
        for card in cards { setCollected(card, collected) }
    }

    func reset() {
        entries = [:]
        lastChangedID = nil
        scheduleSave()
    }

    // MARK: - Import / Export

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Snapshot(entries: entries))
    }

    func importData(_ data: Data, merge: Bool) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Snapshot.self, from: data)
        if merge {
            entries.merge(snapshot.entries) { current, incoming in
                Entry(quantity: max(current.quantity, incoming.quantity),
                      collectedAt: min(current.collectedAt, incoming.collectedAt),
                      favorite: current.favorite || incoming.favorite,
                      note: current.note.isEmpty ? incoming.note : current.note,
                      grading: current.grading ?? incoming.grading)
            }
        } else {
            entries = snapshot.entries
        }
        scheduleSave()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) {
            entries = snapshot.entries
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = Snapshot(entries: entries)
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
