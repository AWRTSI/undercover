import Foundation

/// Moteur central d'analyse du marché : combine détection de sniping, analyse de tendance et
/// prédiction SBC pour produire la liste consolidée d'opportunités du moment.
struct OpportunityDetectionEngine: Sendable {
    /// Seuil de sous-évaluation en dessous duquel une carte est considérée comme "snipée".
    var snipeThreshold: Double = -0.15
    /// Seuil de creux hebdomadaire (ex. après distribution des récompenses de weekend league).
    var trendDipThreshold: Double = -0.10

    private let sbcPrediction = SBCPredictionService()

    /// Point d'entrée principal : analyse un snapshot de marché et les SBC actifs, retourne
    /// toutes les opportunités détectées triées par bénéfice net décroissant.
    func detectOpportunities(players: [Player], sbcs: [SBCRequirement]) -> [MarketAlert] {
        var alerts: [MarketAlert] = []
        alerts.append(contentsOf: detectSnipes(players: players))
        alerts.append(contentsOf: detectTrendDips(players: players))
        alerts.append(contentsOf: detectInvestmentOpportunities(players: players))
        alerts.append(contentsOf: sbcPrediction.predictFodderOpportunities(players: players, sbcs: sbcs))
        return alerts.sorted { $0.netProfit > $1.netProfit }
    }

    /// Détecte les cartes listées significativement sous leur prix moyen du marché (snipe classique).
    func detectSnipes(players: [Player]) -> [MarketAlert] {
        players.compactMap { player -> MarketAlert? in
            guard player.priceDeviation <= snipeThreshold else { return nil }

            let risk = riskLevel(for: player, deviation: player.priceDeviation)
            let deviationPercent = Int(player.priceDeviation * 100)

            return MarketAlert(
                id: UUID(),
                player: player,
                type: .snipe,
                detectedAt: .now,
                buyPrice: player.currentPrice,
                estimatedSellPrice: player.rollingAveragePrice,
                riskLevel: risk,
                rationale: "\(deviationPercent)% sous la moyenne du marché sur 24h"
            )
        }
    }

    /// Détecte les points bas de tendance hebdomadaire (ex. après distribution de récompenses
    /// de weekend league, quand l'offre augmente temporairement et fait chuter les prix).
    func detectTrendDips(players: [Player]) -> [MarketAlert] {
        players.compactMap { player -> MarketAlert? in
            guard player.priceHistory.count >= 6 else { return nil }
            guard player.priceDeviation > snipeThreshold, player.priceDeviation <= trendDipThreshold else { return nil }

            let recentWindow = Array(player.priceHistory.suffix(6))
            let recentAverage = recentWindow.map(\.price).reduce(0, +) / recentWindow.count
            let earlierWindow = Array(player.priceHistory.prefix(max(1, player.priceHistory.count - 6)))
            let earlierAverage = earlierWindow.isEmpty ? recentAverage : earlierWindow.map(\.price).reduce(0, +) / earlierWindow.count

            // Un vrai creux de tendance suppose que le prix a baissé récemment par rapport à la période précédente.
            guard recentAverage < earlierAverage else { return nil }

            let projectedRebound = Int(Double(earlierAverage) * 0.97)
            let risk = riskLevel(for: player, deviation: player.priceDeviation)

            return MarketAlert(
                id: UUID(),
                player: player,
                type: .trend,
                detectedAt: .now,
                buyPrice: player.currentPrice,
                estimatedSellPrice: max(projectedRebound, player.rollingAveragePrice),
                riskLevel: risk,
                rationale: "Creux hebdomadaire détecté, rebond attendu vers le niveau d'avant-baisse"
            )
        }
    }

    /// Détecte les cartes à fort potentiel de plus-value à moyen terme : joueurs performants
    /// (note élevée, rareté significative) dont l'historique de prix montre une tendance
    /// haussière soutenue sur la période observée, plutôt qu'un simple pic ponctuel.
    /// Contrairement au snipe/creux (opportunités immédiates), il s'agit d'un pari sur la
    /// poursuite d'une dynamique déjà engagée — d'où le type "Investissement" dédié.
    func detectInvestmentOpportunities(players: [Player]) -> [MarketAlert] {
        players.compactMap { player -> MarketAlert? in
            guard player.overall >= 85 else { return nil }
            guard [Rarity.rare, .special, .hero, .icon].contains(player.rarity) else { return nil }
            guard player.priceHistory.count >= 8 else { return nil }

            // Compare les bords (premiers/derniers points) plutôt que deux moitiés : une
            // progression graduelle sur toute la période dilue le signal si on moyenne la
            // moitié complète, alors que les extrémités reflètent fidèlement l'ampleur réelle
            // de la tendance observée.
            let edgeWindow = min(4, player.priceHistory.count / 2)
            let earlyWindow = player.priceHistory.prefix(edgeWindow)
            let lateWindow = player.priceHistory.suffix(edgeWindow)
            let earlyAverage = earlyWindow.map(\.price).reduce(0, +) / max(earlyWindow.count, 1)
            let lateAverage = lateWindow.map(\.price).reduce(0, +) / max(lateWindow.count, 1)
            guard earlyAverage > 0 else { return nil }

            let growth = Double(lateAverage - earlyAverage) / Double(earlyAverage)
            guard growth >= 0.08 else { return nil }

            let projectedSellPrice = Int(Double(player.currentPrice) * (1 + min(growth, 0.25)))
            let risk: RiskLevel = growth > 0.15 ? .medium : .low

            return MarketAlert(
                id: UUID(),
                player: player,
                type: .investment,
                detectedAt: .now,
                buyPrice: player.currentPrice,
                estimatedSellPrice: projectedSellPrice,
                riskLevel: risk,
                rationale: "Tendance haussière de \(Int(growth * 100))% observée sur la période, dynamique en cours"
            )
        }
    }

    /// Estime le risque en croisant l'ampleur de la sous-évaluation et la liquidité implicite
    /// (une rareté élevée = marché plus fin = risque plus élevé de ne pas revendre rapidement).
    private func riskLevel(for player: Player, deviation: Double) -> RiskLevel {
        let liquidityRisk: Int
        switch player.rarity {
        case .common: liquidityRisk = 0
        case .rare: liquidityRisk = 1
        case .special: liquidityRisk = 2
        case .hero: liquidityRisk = 2
        case .icon: liquidityRisk = 3
        }

        let magnitudeRisk = abs(deviation) > 0.25 ? 1 : 0
        let score = liquidityRisk + magnitudeRisk

        switch score {
        case 0...1: return .low
        case 2: return .medium
        default: return .high
        }
    }
}
