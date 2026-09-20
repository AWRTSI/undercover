import Foundation

/// Rareté d'une carte, impacte la volatilité et la profondeur de marché.
enum Rarity: String, Codable, CaseIterable, Identifiable, Sendable {
    case common = "Commune"
    case rare = "Rare"
    case special = "Spéciale"
    case icon = "Icône"
    case hero = "Héros"

    var id: String { rawValue }

    /// FUTBIN classe ses cartes sous des dizaines de libellés (TOTW, TOTS, Icon, Hero, Rare
    /// Gold, promos diverses...) que l'app ne distingue pas toutes : on les ramène aux 5
    /// raretés connues, tout le reste (contenu événementiel/promo) devenant "Spéciale".
    init(futbinCardType label: String) {
        let lowered = label.lowercased()
        if lowered.contains("icon") { self = .icon }
        else if lowered.contains("hero") { self = .hero }
        else if lowered.contains("rare") { self = .rare }
        else if lowered.contains("common") { self = .common }
        else { self = .special }
    }
}

enum PlayerPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case gk = "GB", cb = "DC", lb = "DG", rb = "DD"
    case cdm = "MDC", cm = "MC", cam = "MOC", lm = "MG", rm = "MD"
    case lw = "AG", rw = "AD", st = "BU", cf = "AC"

    var id: String { rawValue }

    /// FUTBIN donne des positions en anglais (parfois plusieurs séparées par une virgule pour
    /// les postes secondaires) ; on ne garde que la première, celle qui compte pour le poste
    /// principal affiché sur la carte.
    init(futbinCode raw: String) {
        let code = raw.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        switch code {
        case "GK": self = .gk
        case "CB": self = .cb
        case "LB", "LWB": self = .lb
        case "RB", "RWB": self = .rb
        case "CDM": self = .cdm
        case "CM": self = .cm
        case "CAM": self = .cam
        case "LM": self = .lm
        case "RM": self = .rm
        case "LW": self = .lw
        case "RW": self = .rw
        case "CF": self = .cf
        default: self = .st
        }
    }
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
