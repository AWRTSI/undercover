import Foundation

/// Rareté d'une carte, impacte la volatilité et la profondeur de marché.
enum Rarity: String, Codable, CaseIterable, Identifiable, Sendable {
    case common = "Commune"
    case rare = "Rare"
    case special = "Spéciale"
    case icon = "Icône"
    case hero = "Héros"

    var id: String { rawValue }
}

enum PlayerPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case gk = "GB", cb = "DC", lb = "DG", rb = "DD"
    case cdm = "MDC", cm = "MC", cam = "MOC", lm = "MG", rm = "MD"
    case lw = "AG", rw = "AD", st = "BU", cf = "AC"

    var id: String { rawValue }
}

/// Point d'une série temporelle de prix (chandelle simplifiée BIN marché).
struct PricePoint: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    let timestamp: Date
    let price: Int
}

/// Modèle central représentant une carte joueur sur le marché des transferts.
struct Player: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let club: String
    let nation: String
    let league: String
    let position: PlayerPosition
    let overall: Int
    let rarity: Rarity
    let imageURL: URL?

    /// Prix d'achat immédiat actuellement affiché sur le marché (le plus bas listé).
    var currentPrice: Int
    /// Moyenne mobile du marché sur les dernières 24h, sert de référence pour le sniping.
    var rollingAveragePrice: Int
    /// Historique de prix utilisé pour tracer les courbes de tendance.
    var priceHistory: [PricePoint]

    /// Écart en pourcentage entre le prix courant et la moyenne du marché.
    /// Négatif = la carte est sous-évaluée (opportunité d'achat).
    var priceDeviation: Double {
        guard rollingAveragePrice > 0 else { return 0 }
        return (Double(currentPrice) - Double(rollingAveragePrice)) / Double(rollingAveragePrice)
    }
}

extension Player {
    /// Prix net après application de la taxe de revente de 5% appliquée par le jeu.
    static func netSalePrice(listingPrice: Int, taxRate: Double = 0.05) -> Int {
        Int(Double(listingPrice) * (1 - taxRate))
    }
}
