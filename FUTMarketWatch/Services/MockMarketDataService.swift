import Foundation

/// Implémentation factice de `MarketDataServiceProtocol` : simule les fluctuations de prix en
/// mémoire pour permettre de développer et tester l'UI et l'algorithme sans backend actif.
///
/// Déclaré comme `actor` (et non `final class`) car Dashboard, Marché et Filons appellent tous
/// `priceUpdatesStream()` en parallèle sur cette même instance partagée : sans isolation, les
/// multiples tâches internes mutaient le tableau `players` en même temps depuis des threads
/// différents, ce qui déclenche une violation d'exclusivité Swift (plantage aléatoire et
/// difficile à reproduire). L'acteur garantit qu'un seul accès à `players` a lieu à la fois.
actor MockMarketDataService: MarketDataServiceProtocol {
    private var players: [Player]
    private let sbcs: [SBCRequirement]

    init(players: [Player] = MockData.players, sbcs: [SBCRequirement] = MockData.activeSBCs) {
        self.players = players
        self.sbcs = sbcs
    }

    func fetchMarketSnapshot() async throws -> [Player] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return players
    }

    func fetchPriceHistory(for playerID: UUID, since: Date) async throws -> [PricePoint] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return players.first(where: { $0.id == playerID })?.priceHistory.filter { $0.timestamp >= since } ?? []
    }

    func fetchActiveSBCs() async throws -> [SBCRequirement] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return sbcs
    }

    /// Le mock n'a de toute façon qu'un petit catalogue fixe : une "recherche à la demande"
    /// revient juste à filtrer localement, contrairement à `RemoteMarketDataService` qui, lui,
    /// interroge vraiment une source externe au-delà de ce qui est déjà chargé.
    func searchPlayers(query: String) async throws -> [Player] {
        try await Task.sleep(nanoseconds: 150_000_000)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return players }
        return players.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Simule un flux de mises à jour en faisant fluctuer aléatoirement un joueur toutes les
    /// quelques secondes, à la manière d'un WebSocket de marché en temps réel. `nonisolated` pour
    /// rester appelable sans `await` (comme le veut le protocole) ; la tâche interne repasse par
    /// l'acteur via `await` à chaque mutation pour rester thread-safe.
    nonisolated func priceUpdatesStream() -> AsyncStream<Player> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    guard let updated = await self.applyRandomFluctuation() else { continue }
                    continuation.yield(updated)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func applyRandomFluctuation() -> Player? {
        guard let index = players.indices.randomElement() else { return nil }
        var updated = players[index]
        let variation = Double.random(in: -0.08...0.05)
        let newPrice = max(150, Int(Double(updated.currentPrice) * (1 + variation)))
        updated.currentPrice = newPrice
        updated.priceHistory.append(PricePoint(timestamp: .now, price: newPrice))
        players[index] = updated
        return updated
    }
}
