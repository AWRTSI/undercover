import Foundation

/// Niveau de risque estimé d'une opportunité (liquidité, volatilité, fiabilité de la source).
enum RiskLevel: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case low = "Faible"
    case medium = "Moyen"
    case high = "Élevé"

    var id: String { rawValue }

    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Catégorise l'origine de la détection, utile pour filtrer et pour l'affichage dans le flux.
enum AlertType: String, Codable, CaseIterable, Identifiable, Sendable {
    case snipe = "Snipe"
    case trend = "Tendance"
    case sbcFodder = "Fodder SBC"
    case investment = "Investissement"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .snipe: return "bolt.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .sbcFodder: return "square.stack.3d.up.fill"
        case .investment: return "banknote.fill"
        }
    }
}

/// Une opportunité détectée par le moteur, prête à être notifiée à l'utilisateur.
struct MarketAlert: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let player: Player
    let type: AlertType
    let detectedAt: Date

    /// Prix cible auquel acheter la carte pour saisir l'opportunité.
    let buyPrice: Int
    /// Prix de revente estimé, basé sur la moyenne du marché ou une prédiction de tendance.
    let estimatedSellPrice: Int
    let riskLevel: RiskLevel

    /// Courte justification lisible par l'utilisateur (ex. "-18% vs moyenne 24h").
    let rationale: String

    /// Bénéfice net après taxe de revente de 5%.
    var netProfit: Int {
        Player.netSalePrice(listingPrice: estimatedSellPrice) - buyPrice
    }

    var profitMarginPercent: Double {
        guard buyPrice > 0 else { return 0 }
        return Double(netProfit) / Double(buyPrice)
    }
}
