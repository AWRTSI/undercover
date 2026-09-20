import Foundation
import SwiftData

/// Gère l'ajout/suppression de cartes suivies et rapproche la watchlist des prix marché
/// courants pour signaler quand une carte suivie atteint son prix cible.
@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var currentPricesByPlayerID: [UUID: Player] = [:]

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func refreshMarketPrices() async {
        guard let players = try? await dependencies.marketDataService.fetchMarketSnapshot() else { return }
        currentPricesByPlayerID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
    }

    func marketPrice(for item: WatchlistItem) -> Int? {
        currentPricesByPlayerID[item.playerID]?.currentPrice
    }

    /// Une carte suivie "a atteint sa cible" quand son prix marché courant est au niveau ou
    /// sous le prix d'achat visé par l'utilisateur.
    func hasReachedTarget(_ item: WatchlistItem) -> Bool {
        guard let price = marketPrice(for: item) else { return false }
        return price <= item.targetBuyPrice
    }

    func addToWatchlist(player: Player, targetBuyPrice: Int, context: ModelContext) {
        let item = WatchlistItem(
            playerID: player.id,
            playerName: player.name,
            club: player.club,
            overall: player.overall,
            targetBuyPrice: targetBuyPrice
        )
        context.insert(item)
    }

    func remove(_ item: WatchlistItem, context: ModelContext) {
        context.delete(item)
    }
}
