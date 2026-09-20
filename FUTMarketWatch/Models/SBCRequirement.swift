import Foundation

/// Type de contrepartie demandée par un SBC (Squad Building Challenge) ou un objectif.
enum SBCChallengeType: String, Codable, CaseIterable, Identifiable, Sendable {
    case squadBuilding = "SBC"
    case objective = "Objectif"
    case album = "Album"

    var id: String { rawValue }
}

/// Un critère unique dans un segment de SBC (ex. "OVR minimum 84", "Ligue: LaLiga").
struct SBCCriterion: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let label: String

    enum Kind: String, Codable, Sendable {
        case minOverall, exactLeague, exactNation, minRareCount, minChemistry, minSquadRating
    }

    let kind: Kind
    /// Valeur numérique ou identifiant textuel selon `kind` (ex. "84", "LaLiga").
    let value: String
}

/// Représente un SBC/objectif à venir ou actif, utilisé pour anticiper la demande de fodder.
struct SBCRequirement: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let type: SBCChallengeType
    let expiresAt: Date?
    let criteria: [SBCCriterion]

    /// Coût estimé en pièces pour compléter le challenge avec le marché actuel.
    let estimatedCost: Int?

    /// Récompense attendue (texte libre, ex. "Joueur Rare 84+ garanti").
    let expectedReward: String

    /// Score de popularité prédit (0-1) : plus haut = plus de demande anticipée sur les critères,
    /// donc plus d'intérêt à acheter le fodder correspondant en avance.
    let demandScore: Double
}

extension SBCRequirement {
    /// Vérifie si un joueur satisfait tous les critères de type "filtre exact" du challenge,
    /// pour proposer des candidats fodder pertinents dans la watchlist.
    func matches(_ player: Player) -> Bool {
        criteria.allSatisfy { criterion in
            switch criterion.kind {
            case .minOverall:
                guard let threshold = Int(criterion.value) else { return true }
                return player.overall >= threshold
            case .exactLeague:
                return player.league.caseInsensitiveCompare(criterion.value) == .orderedSame
            case .exactNation:
                return player.nation.caseInsensitiveCompare(criterion.value) == .orderedSame
            case .minRareCount, .minChemistry, .minSquadRating:
                // Critères calculés au niveau de l'équipe complète, non applicables à une carte seule.
                return true
            }
        }
    }
}
