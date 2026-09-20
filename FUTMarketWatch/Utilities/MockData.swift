import Foundation

/// Générateur de données factices utilisé par `MockMarketDataService` pour permettre le
/// développement et les previews SwiftUI sans dépendre d'une API de marché active.
enum MockData {

    /// Génère un historique dont la trajectoire converge réellement vers `endDeviationPercent`
    /// (progression quasi linéaire + bruit léger), plutôt qu'un bruit purement aléatoire déconnecté
    /// du prix courant. Sans cela, le prix affiché pouvait dévier de -19% de la moyenne pendant que
    /// l'historique généré séparément ne montrait aucune tendance cohérente : la détection de
    /// "creux hebdomadaire" (qui compare le début et la fin de l'historique) ne se déclenchait
    /// alors quasiment jamais, même quand une carte était objectivement sous-évaluée.
    static func generatePriceHistory(around average: Int, endDeviationPercent: Double = 0, points: Int = 24) -> [PricePoint] {
        var history: [PricePoint] = []
        let now = Date()
        let noiseRange = max(1, Int(Double(average) * 0.02))
        for i in stride(from: points, through: 0, by: -1) {
            let progress = 1 - (Double(i) / Double(points))
            let trendPrice = Double(average) * (1 + endDeviationPercent * progress)
            let noise = Int.random(in: -noiseRange...noiseRange)
            let price = max(150, Int(trendPrice) + noise)
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
        let history = generatePriceHistory(around: averagePrice, endDeviationPercent: deviationPercent)
        let current = history.last?.price ?? averagePrice
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
    /// pour exercer le moteur de détection sur des cas variés (snipe net, creux de tendance,
    /// dynamique haussière, fodder SBC, marché stable, survalorisé). Volontairement plus large
    /// qu'un simple échantillon de 10 cartes pour que le marché simulé se sente vivant et que
    /// chaque catégorie d'alerte ait des candidats fiables.
    static var players: [Player] = [
        // Snipe (sous-évaluation nette, < -15%)
        makePlayer(name: "K. Mbappé", club: "Real Madrid", nation: "France", league: "LaLiga", position: .st, overall: 91, rarity: .special, averagePrice: 2_950_000, deviationPercent: -0.19),
        makePlayer(name: "V. van Dijk", club: "Liverpool", nation: "Pays-Bas", league: "Premier League", position: .cb, overall: 90, rarity: .rare, averagePrice: 680_000, deviationPercent: -0.22),
        makePlayer(name: "Pedri", club: "Barcelone", nation: "Espagne", league: "LaLiga", position: .cm, overall: 87, rarity: .rare, averagePrice: 245_000, deviationPercent: -0.16),
        makePlayer(name: "A. Hakimi", club: "PSG", nation: "Maroc", league: "Ligue 1", position: .rb, overall: 86, rarity: .rare, averagePrice: 165_000, deviationPercent: -0.17),

        // Creux de tendance hebdomadaire (-10% à -15%)
        makePlayer(name: "R. Lewandowski", club: "Barcelone", nation: "Pologne", league: "LaLiga", position: .st, overall: 89, rarity: .rare, averagePrice: 320_000, deviationPercent: -0.13),
        makePlayer(name: "A. Griezmann", club: "Atlético Madrid", nation: "France", league: "LaLiga", position: .cf, overall: 87, rarity: .rare, averagePrice: 260_000, deviationPercent: -0.13),
        makePlayer(name: "F. Wirtz", club: "Bayer Leverkusen", nation: "Allemagne", league: "Bundesliga", position: .cam, overall: 87, rarity: .special, averagePrice: 480_000, deviationPercent: -0.12),
        makePlayer(name: "W. Saliba", club: "Arsenal", nation: "France", league: "Premier League", position: .cb, overall: 86, rarity: .rare, averagePrice: 190_000, deviationPercent: -0.14),

        // Tendance haussière soutenue (investissement, note 85+, rareté significative)
        makePlayer(name: "J. Musiala", club: "Bayern Munich", nation: "Allemagne", league: "Bundesliga", position: .cam, overall: 88, rarity: .rare, averagePrice: 410_000, deviationPercent: 0.16),
        makePlayer(name: "O. Dembélé", club: "PSG", nation: "France", league: "Ligue 1", position: .rw, overall: 88, rarity: .rare, averagePrice: 210_000, deviationPercent: 0.18),
        makePlayer(name: "E. Haaland", club: "Man City", nation: "Norvège", league: "Premier League", position: .st, overall: 91, rarity: .special, averagePrice: 3_200_000, deviationPercent: 0.13),

        // Marché stable / survalorisé (aucune alerte attendue, sert de contrôle)
        makePlayer(name: "J. Bellingham", club: "Real Madrid", nation: "Angleterre", league: "LaLiga", position: .cam, overall: 89, rarity: .rare, averagePrice: 1_450_000, deviationPercent: -0.04),
        makePlayer(name: "Bukayo Saka", club: "Arsenal", nation: "Angleterre", league: "Premier League", position: .rw, overall: 88, rarity: .rare, averagePrice: 410_000, deviationPercent: 0.02),
        makePlayer(name: "Rodri", club: "Man City", nation: "Espagne", league: "Premier League", position: .cdm, overall: 90, rarity: .rare, averagePrice: 505_000, deviationPercent: -0.03),
        makePlayer(name: "Declan Rice", club: "Arsenal", nation: "Angleterre", league: "Premier League", position: .cdm, overall: 87, rarity: .rare, averagePrice: 310_000, deviationPercent: -0.03),
        makePlayer(name: "M. ter Stegen", club: "Barcelone", nation: "Allemagne", league: "LaLiga", position: .gk, overall: 87, rarity: .rare, averagePrice: 155_000, deviationPercent: -0.06),
        makePlayer(name: "A. Putellas", club: "Barcelone", nation: "Espagne", league: "Liga F", position: .cam, overall: 91, rarity: .icon, averagePrice: 1_100_000, deviationPercent: -0.05),

        // Fodder SBC bon marché (correspond aux critères des SBC actifs ci-dessous)
        makePlayer(name: "Endrick", club: "Real Madrid", nation: "Brésil", league: "LaLiga", position: .st, overall: 84, rarity: .rare, averagePrice: 145_000, deviationPercent: -0.12),
        makePlayer(name: "Fodder Rare Espagne", club: "Villarreal", nation: "Espagne", league: "LaLiga", position: .cm, overall: 83, rarity: .common, averagePrice: 8_000, deviationPercent: 0.0),
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
