import Foundation

/// Erreurs pouvant survenir lors de l'accès aux données de marché distantes.
enum MarketDataError: Error, LocalizedError {
    case network(underlying: Error)
    case decoding(underlying: Error)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .network: return "Impossible de contacter le service de marché."
        case .decoding: return "Réponse du serveur illisible."
        case .unauthorized: return "Session expirée, reconnexion nécessaire."
        case .unknown: return "Une erreur inconnue est survenue."
        }
    }
}

/// Couche d'abstraction de la source de données du marché des transferts.
/// Permet de brancher indifféremment un mock local, une API REST, ou un flux WebSocket temps réel.
protocol MarketDataServiceProtocol {
    /// Récupère l'état courant du marché pour un ensemble de joueurs (prix, historique).
    func fetchMarketSnapshot() async throws -> [Player]

    /// Récupère l'historique de prix détaillé d'un joueur sur une fenêtre donnée.
    func fetchPriceHistory(for playerID: UUID, since: Date) async throws -> [PricePoint]

    /// Récupère les SBC et objectifs actifs ou à venir, utilisés pour la prédiction de demande.
    func fetchActiveSBCs() async throws -> [SBCRequirement]

    /// Ouvre un flux continu de mises à jour de prix (WebSocket ou polling déguisé en stream).
    /// L'appelant doit itérer sur le flux tant que l'écran concerné est visible.
    func priceUpdatesStream() -> AsyncStream<Player>
}
