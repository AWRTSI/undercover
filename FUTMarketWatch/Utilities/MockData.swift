import Foundation

/// Générateur de données factices utilisé par `MockMarketDataService` pour permettre le
/// développement et les previews SwiftUI sans dépendre d'une API de marché active.
enum MockData {

    static func generatePriceHistory(around average: Int, points: Int = 24) -> [PricePoint] {
        var history: [PricePoint] = []
        let now = Date()
        var price = average
        for i in stride(from: points, through: 0, by: -1) {
            let noise = Int.random(in: -Int(Double(average) * 0.06)...Int(Double(average) * 0.06))
            price = max(150, price + noise)
            let timestamp = Calendar.current.date(byAdding: .hour, value: -i, to: now) ?? now
            history.append(PricePoint(timestamp: timestamp, price: price))
        }
        return history
    }

    static func makePlayer(
        name: String,
        club: String,
        nation: String,
        league: String,
        position: PlayerPosition,
        overall: Int,
        rarity: Rarity,
        averagePrice: Int,
        deviationPercent: Double = 0
    ) -> Player {
        let history = generatePriceHistory(around: averagePrice)
        let current = Int(Double(averagePrice) * (1 + deviationPercent))
        return Player(
            id: UUID(),
            name: name,
            club: club,
            nation: nation,
            league: league,
            position: position,
            overall: overall,
            rarity: rarity,
            imageURL: nil,
            currentPrice: max(150, current),
            rollingAveragePrice: averagePrice,
            priceHistory: history
        )
    }

    /// Panel de cartes couvrant plusieurs ligues, rarétés et niveaux de sous/sur-évaluation,
    /// pour exercer le moteur de détection sur des cas variés (snipe net, marché stable, survalorisé).
    static var players: [Player] = [
        makePlayer(name: "K. Mbappé", club: "Real Madrid", nation: "France", league: "LaLiga", position: .st, overall: 91, rarity: .special, averagePrice: 2_950_000, deviationPercent: -0.19),
        makePlayer(name: "J. Bellingham", club: "Real Madrid", nation: "Angleterre", league: "LaLiga", position: .cam, overall: 89, rarity: .rare, averagePrice: 1_450_000, deviationPercent: -0.04),
        makePlayer(name: "V. van Dijk", club: "Liverpool", nation: "Pays-Bas", league: "Premier League", position: .cb, overall: 90, rarity: .rare, averagePrice: 680_000, deviationPercent: -0.22),
        makePlayer(name: "E. Haaland", club: "Man City", nation: "Norvège", league: "Premier League", position: .st, overall: 91, rarity: .special, averagePrice: 3_200_000, deviationPercent: 0.06),
        makePlayer(name: "Pedri", club: "Barcelone", nation: "Espagne", league: "LaLiga", position: .cm, overall: 87, rarity: .rare, averagePrice: 245_000, deviationPercent: -0.16),
        makePlayer(name: "Bukayo Saka", club: "Arsenal", nation: "Angleterre", league: "Premier League", position: .rw, overall: 88, rarity: .rare, averagePrice: 410_000, deviationPercent: 0.02),
        makePlayer(name: "R. Lewandowski", club: "Barcelone", nation: "Pologne", league: "LaLiga", position: .st, overall: 89, rarity: .rare, averagePrice: 320_000, deviationPercent: -0.11),
        makePlayer(name: "Rodri", club: "Man City", nation: "Espagne", league: "Premier League", position: .cdm, overall: 90, rarity: .rare, averagePrice: 505_000, deviationPercent: -0.09),
        makePlayer(name: "Joueur Rare Ordinaire", club: "Lyon", nation: "France", league: "Ligue 1", position: .lb, overall: 78, rarity: .common, averagePrice: 3_500, deviationPercent: -0.05),
        makePlayer(name: "Fodder Or Basique", club: "Séville", nation: "Espagne", league: "LaLiga", position: .cb, overall: 75, rarity: .common, averagePrice: 1_200, deviationPercent: 0.0),
    ]

    static var activeSBCs: [SBCRequirement] = [
        SBCRequirement(
            id: UUID(),
            title: "Défi Hebdomadaire — Milieu LaLiga",
            type: .squadBuilding,
            expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: .now),
            criteria: [
                SBCCriterion(id: UUID(), label: "OVR minimum 84", kind: .minOverall, value: "84"),
                SBCCriterion(id: UUID(), label: "Ligue: LaLiga", kind: .exactLeague, value: "LaLiga"),
            ],
            estimatedCost: 45_000,
            expectedReward: "Pack Or Rare Jumbo",
            demandScore: 0.72
        ),
        SBCRequirement(
            id: UUID(),
            title: "Objectif Saisonnier — Nation Espagne",
            type: .objective,
            expiresAt: Calendar.current.date(byAdding: .day, value: 6, to: .now),
            criteria: [
                SBCCriterion(id: UUID(), label: "Nation: Espagne", kind: .exactNation, value: "Espagne"),
                SBCCriterion(id: UUID(), label: "OVR minimum 82", kind: .minOverall, value: "82"),
            ],
            estimatedCost: 28_000,
            expectedReward: "Joueur Rare 84+ garanti",
            demandScore: 0.58
        ),
        SBCRequirement(
            id: UUID(),
            title: "Album Icônes — Fondations",
            type: .album,
            expiresAt: nil,
            criteria: [
                SBCCriterion(id: UUID(), label: "OVR minimum 83", kind: .minOverall, value: "83")
            ],
            estimatedCost: nil,
            expectedReward: "Icône garantie à la complétion",
            demandScore: 0.85
        ),
    ]
}
