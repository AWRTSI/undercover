import Foundation
import SwiftData

/// Carte suivie par l'utilisateur, persistée localement via SwiftData.
@Model
final class WatchlistItem {
    @Attribute(.unique) var id: UUID
    var playerID: UUID
    var playerName: String
    var club: String
    var overall: Int
    var targetBuyPrice: Int
    var addedAt: Date

    init(id: UUID = UUID(), playerID: UUID, playerName: String, club: String, overall: Int, targetBuyPrice: Int, addedAt: Date = .now) {
        self.id = id
        self.playerID = playerID
        self.playerName = playerName
        self.club = club
        self.overall = overall
        self.targetBuyPrice = targetBuyPrice
        self.addedAt = addedAt
    }
}
