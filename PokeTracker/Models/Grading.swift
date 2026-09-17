import Foundation

enum GradingCompany: String, Codable, CaseIterable, Identifiable {
    case psa = "PSA"
    case cgc = "CGC"
    case bgs = "BGS"
    case tag = "TAG"

    var id: String { rawValue }
    var title: String { rawValue }

    var fullName: String {
        switch self {
        case .psa: return "Professional Sports Authenticator"
        case .cgc: return "Certified Guaranty Company"
        case .bgs: return "Beckett Grading Services"
        case .tag: return "TAG Grading"
        }
    }

    /// Grades this company issues, highest first.
    var grades: [Double] {
        switch self {
        case .psa: return [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        case .cgc, .bgs, .tag: return [10, 9.5, 9, 8.5, 8, 7.5, 7, 6.5, 6, 5, 4, 3, 2, 1]
        }
    }

    /// Titles PriceCharting and eBay sellers use for a grade, e.g. "PSA 10", "CGC 10 Pristine".
    func aliases(for grade: Double) -> [String] {
        let g = Grade.label(grade)
        switch self {
        case .psa: return ["PSA \(g)"] + (grade == 10 ? ["PSA GEM MT 10", "PSA GEM MINT 10"] : [])
        case .cgc: return ["CGC \(g)"] + (grade == 10 ? ["CGC 10 Pristine", "CGC Pristine 10", "CGC 10 Gem Mint", "CGC Gem Mint 10"] : [])
        case .bgs: return ["BGS \(g)", "Beckett \(g)"] + (grade == 10 ? ["BGS 10 Black", "BGS Black Label 10", "BGS 10 Pristine"] : [])
        case .tag: return ["TAG \(g)"]
        }
    }
}

enum Grade {
    static func label(_ grade: Double) -> String {
        grade == grade.rounded() ? String(Int(grade)) : String(format: "%.1f", grade)
    }
}

/// How a collected card is held: raw, or slabbed by a grading company.
struct Grading: Codable, Hashable {
    var company: GradingCompany
    var grade: Double
    var certNumber: String = ""

    var title: String { "\(company.title) \(Grade.label(grade))" }
}
