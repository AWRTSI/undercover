import Foundation
import SwiftData

/// Gère le portefeuille de cartes détenues : calcul des bénéfices/pertes latents et réalisés,
/// et valeur globale du club/stock à des fins de suivi.
@MainActor
final class PortfolioViewModel: ObservableObject {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Rafraîchit le dernier prix marché connu de chaque position détenue, pour recalculer
    /// la valeur latente du portefeuille.
    func refreshMarketPrices(holdings: [HoldingPosition], context: ModelContext) async {
        guard let players = try? await dependencies.marketDataService.fetchMarketSnapshot() else { return }
        let priceByID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.currentPrice) })

        for holding in holdings {
            if let latestPrice = priceByID[holding.playerID] {
                holding.lastKnownMarketPrice = latestPrice
            }
        }
    }

    func recordPurchase(player: Player, buyPrice: Int, context: ModelContext) {
        let holding = HoldingPosition(
            playerID: player.id,
            playerName: player.name,
            club: player.club,
            overall: player.overall,
            buyPrice: buyPrice,
            lastKnownMarketPrice: player.currentPrice
        )
        context.insert(holding)

        let transaction = Transaction(playerID: player.id, playerName: player.name, side: .buy, amount: buyPrice)
        context.insert(transaction)
    }

    func recordSale(holding: HoldingPosition, sellPrice: Int, context: ModelContext) {
        let netProceeds = Player.netSalePrice(listingPrice: sellPrice)
        let transaction = Transaction(playerID: holding.playerID, playerName: holding.playerName, side: .sell, amount: netProceeds)
        context.insert(transaction)
        context.delete(holding)
    }

    func totalPortfolioValue(holdings: [HoldingPosition]) -> Int {
        holdings.reduce(0) { $0 + Player.netSalePrice(listingPrice: $1.lastKnownMarketPrice) }
    }

    func totalUnrealizedProfit(holdings: [HoldingPosition]) -> Int {
        holdings.reduce(0) { $0 + $1.unrealizedNetProfit }
    }

    func totalRealizedProfit(transactions: [Transaction]) -> Int {
        let bought = transactions.filter { $0.side == .buy }.reduce(0) { $0 + $1.amount }
        let sold = transactions.filter { $0.side == .sell }.reduce(0) { $0 + $1.amount }
        return sold - bought
    }
}
