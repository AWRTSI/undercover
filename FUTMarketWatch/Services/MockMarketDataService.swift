import Foundation

/// Implémentation factice de `MarketDataServiceProtocol` : simule les fluctuations de prix en
/// mémoire pour permettre de développer et tester l'UI et l'algorithme sans backend actif.
final class MockMarketDataService: MarketDataServiceProtocol {
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

    /// Simule un flux de mises à jour en faisant fluctuer aléatoirement un joueur toutes les
    /// quelques secondes, à la manière d'un WebSocket de marché en temps réel.
    func priceUpdatesStream() -> AsyncStream<Player> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    guard let index = players.indices.randomElement() else { continue }
                    var updated = players[index]
                    let variation = Double.random(in: -0.08...0.05)
                    let newPrice = max(150, Int(Double(updated.currentPrice) * (1 + variation)))
                    updated.currentPrice = newPrice
                    updated.priceHistory.append(PricePoint(timestamp: .now, price: newPrice))
                    players[index] = updated
                    continuation.yield(updated)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
