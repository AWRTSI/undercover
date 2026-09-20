import Foundation
import SwiftData

enum TransactionSide: String, Codable {
    case buy = "Achat"
    case sell = "Vente"
}

/// Ligne d'historique du portefeuille (achat ou vente), persistée localement via SwiftData.
@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var playerID: UUID
    var playerName: String
    var side: TransactionSide
    var amount: Int
    var date: Date
    /// Référence à l'achat correspondant lorsqu'il s'agit d'une vente, pour calculer le P&L.
    var linkedBuyTransactionID: UUID?

    init(id: UUID = UUID(), playerID: UUID, playerName: String, side: TransactionSide, amount: Int, date: Date = .now, linkedBuyTransactionID: UUID? = nil) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.side = side
        self.amount = amount
        self.date = date
        self.linkedBuyTransactionID = linkedBuyTransactionID
    }
}

/// Position actuellement détenue dans le club (carte achetée, pas encore revendue).
@Model
final class HoldingPosition {
    @Attribute(.unique) var id: UUID
    var playerID: UUID
    var playerName: String
    var club: String
    var overall: Int
    var buyPrice: Int
    var buyDate: Date
    /// Dernier prix marché connu, mis à jour périodiquement pour calculer la valeur latente.
    var lastKnownMarketPrice: Int

    init(id: UUID = UUID(), playerID: UUID, playerName: String, club: String, overall: Int, buyPrice: Int, buyDate: Date = .now, lastKnownMarketPrice: Int) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.club = club
        self.overall = overall
        self.buyPrice = buyPrice
        self.buyDate = buyDate
        self.lastKnownMarketPrice = lastKnownMarketPrice
    }

    /// Plus-value latente nette si la position était revendue au prix marché actuel.
    var unrealizedNetProfit: Int {
        Player.netSalePrice(listingPrice: lastKnownMarketPrice) - buyPrice
    }
}
