import Foundation
import Observation
import Security

/// User preferences. Small values live in UserDefaults; the Card Ladder key lives in the Keychain.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var cardLadderAPIKey: String {
        didSet { Keychain.set(cardLadderAPIKey, for: Keychain.cardLadderKey) }
    }

    var cardLadderBaseURL: String {
        didSet { defaults.set(cardLadderBaseURL, forKey: "cardLadderBaseURL") }
    }

    var autoRefreshPrices: Bool {
        didSet { defaults.set(autoRefreshPrices, forKey: "autoRefreshPrices") }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }

    var gridColumns: Int {
        didSet { defaults.set(gridColumns, forKey: "gridColumns") }
    }

    var dimCollectedCards: Bool {
        didSet { defaults.set(dimCollectedCards, forKey: "dimCollectedCards") }
    }

    var sparkleEffects: Bool {
        didSet { defaults.set(sparkleEffects, forKey: "sparkleEffects") }
    }

    /// Which expansion the app is showing.
    var selectedSetID: String {
        didSet {
            defaults.set(selectedSetID, forKey: "selectedSetID")
            PokeTheme.apply(setID: selectedSetID)
        }
    }

    /// Last grading company / grade the user looked at in the graded price panel.
    var preferredGradingCompany: GradingCompany {
        didSet { defaults.set(preferredGradingCompany.rawValue, forKey: "preferredGradingCompany") }
    }

    var preferredGrade: Double {
        didSet { defaults.set(preferredGrade, forKey: "preferredGrade") }
    }

    nonisolated static let defaultCardLadderBaseURL = "https://api.parse.bot/scraper/97d5f4bc-6c65-4546-8f71-76149a5533cb"

    init() {
        cardLadderAPIKey = Keychain.get(Keychain.cardLadderKey) ?? ""
        cardLadderBaseURL = defaults.string(forKey: "cardLadderBaseURL") ?? Self.defaultCardLadderBaseURL
        autoRefreshPrices = defaults.object(forKey: "autoRefreshPrices") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        gridColumns = defaults.object(forKey: "gridColumns") as? Int ?? 3
        dimCollectedCards = defaults.object(forKey: "dimCollectedCards") as? Bool ?? true
        sparkleEffects = defaults.object(forKey: "sparkleEffects") as? Bool ?? true
        selectedSetID = defaults.string(forKey: "selectedSetID") ?? CardSet.order[0]
        preferredGradingCompany = GradingCompany(rawValue: defaults.string(forKey: "preferredGradingCompany") ?? "") ?? .psa
        preferredGrade = defaults.object(forKey: "preferredGrade") as? Double ?? 10
        PokeTheme.apply(setID: selectedSetID)
    }

    var hasCardLadderKey: Bool { !cardLadderAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// Minimal Keychain wrapper for storing API keys.
enum Keychain {
    static let cardLadderKey = "com.jjmeier.PokeTracker.cardladder.apikey"

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
