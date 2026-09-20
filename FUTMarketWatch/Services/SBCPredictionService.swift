import Foundation

/// Analyse les SBC/objectifs/albums actifs pour anticiper la demande de fodder et générer des
/// alertes d'investissement sur les cartes qui correspondent aux critères les plus demandés.
struct SBCPredictionService {

    /// Croise les SBC actifs avec le catalogue de joueurs pour identifier les cartes fodder
    /// susceptibles de monter en prix (forte demande prévue, ratio critère/prix favorable).
    func predictFodderOpportunities(players: [Player], sbcs: [SBCRequirement]) -> [MarketAlert] {
        var alerts: [MarketAlert] = []

        for sbc in sbcs where sbc.demandScore >= 0.5 {
            let matchingPlayers = players
                .filter { sbc.matches($0) }
                .filter { $0.rarity == .common || $0.rarity == .rare }
                .sorted { $0.currentPrice < $1.currentPrice }
                .prefix(3)

            for player in matchingPlayers {
                let projectedUplift = 1 + (sbc.demandScore * 0.25)
                let estimatedSellPrice = Int(Double(player.currentPrice) * projectedUplift)

                let risk: RiskLevel = sbc.expiresAt == nil ? .medium : .low

                let daysLeft = sbc.expiresAt.map {
                    Calendar.current.dateComponents([.day], from: .now, to: $0).day ?? 0
                }
                let expiryNote = daysLeft.map { "expire dans \($0)j" } ?? "sans expiration connue"

                let alert = MarketAlert(
                    id: UUID(),
                    player: player,
                    type: .sbcFodder,
                    detectedAt: .now,
                    buyPrice: player.currentPrice,
                    estimatedSellPrice: estimatedSellPrice,
                    riskLevel: risk,
                    rationale: "Correspond aux critères de « \(sbc.title) » (\(expiryNote)), demande prédite \(Int(sbc.demandScore * 100))%"
                )
                alerts.append(alert)
            }
        }

        return alerts
    }
}
