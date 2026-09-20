import Foundation

/// Préférences utilisateur pour filtrer les opportunités remontées par le moteur de détection.
/// Persisté via SwiftData pour rester configurable sans redémarrer l'app.
import SwiftData

@Model
final class UserFilterSettings {
    /// Budget disponible en pièces ; les opportunités dont le prix d'achat dépasse ce montant sont ignorées.
    var availableBudget: Int
    /// Bénéfice net minimum (en pièces) requis pour déclencher une notification.
    var minimumNetProfit: Int
    /// Marge minimum en pourcentage requise en plus du bénéfice net minimum.
    var minimumMarginPercent: Double
    /// Niveau de risque maximum accepté ; les alertes plus risquées sont filtrées.
    var maxRiskLevelRaw: String
    /// Types d'alertes activés (snipe, tendance, fodder SBC, investissement).
    var enabledAlertTypesRaw: [String]
    /// Marché ciblé (Console = PS5/Xbox, ou PC) : les prix EA diffèrent réellement entre les deux.
    /// Tant qu'aucune vraie source de données n'est branchée (voir `RemoteMarketDataService`),
    /// ce réglage ne fait qu'indiquer l'intention pour l'intégration future — le mock ne
    /// simule qu'un seul marché générique, non spécifique à une plateforme.
    var platformRaw: String
    /// URL du service de scraping FUTBIN déployé (voir `scraper-service/`), ex.
    /// "https://fut-market-scraper.onrender.com". Vide = données simulées (mock).
    var apiBaseURLString: String

    /// Valeurs par défaut volontairement permissives : un premier lancement doit montrer des
    /// opportunités concrètes plutôt qu'un flux vide, quitte à ce que l'utilisateur resserre
    /// ensuite ses critères dans les Réglages. Un budget par défaut de 100 000 pièces, par
    /// exemple, filtrait silencieusement la quasi-totalité du catalogue (cartes à 150k-3M),
    /// donnant l'impression que l'app "ne trouvait rien" alors qu'elle appliquait juste un
    /// filtre trop strict.
    init(
        availableBudget: Int = 3_000_000,
        minimumNetProfit: Int = 500,
        minimumMarginPercent: Double = 0.05,
        maxRiskLevel: RiskLevel = .medium,
        enabledAlertTypes: [AlertType] = AlertType.allCases,
        platform: GamingPlatform = .console,
        apiBaseURLString: String = ""
    ) {
        self.availableBudget = availableBudget
        self.minimumNetProfit = minimumNetProfit
        self.minimumMarginPercent = minimumMarginPercent
        self.maxRiskLevelRaw = maxRiskLevel.rawValue
        self.enabledAlertTypesRaw = enabledAlertTypes.map(\.rawValue)
        self.platformRaw = platform.rawValue
        self.apiBaseURLString = apiBaseURLString
    }

    var maxRiskLevel: RiskLevel {
        get { RiskLevel(rawValue: maxRiskLevelRaw) ?? .medium }
        set { maxRiskLevelRaw = newValue.rawValue }
    }

    var platform: GamingPlatform {
        get { GamingPlatform(rawValue: platformRaw) ?? .console }
        set { platformRaw = newValue.rawValue }
    }

    var enabledAlertTypes: Set<AlertType> {
        get { Set(enabledAlertTypesRaw.compactMap(AlertType.init(rawValue:))) }
        set { enabledAlertTypesRaw = newValue.map(\.rawValue) }
    }

    /// Décide si une alerte respecte l'ensemble des préférences de l'utilisateur.
    func accepts(_ alert: MarketAlert) -> Bool {
        guard enabledAlertTypes.contains(alert.type) else { return false }
        guard alert.buyPrice <= availableBudget else { return false }
        guard alert.netProfit >= minimumNetProfit else { return false }
        guard alert.profitMarginPercent >= minimumMarginPercent else { return false }
        guard alert.riskLevel <= maxRiskLevel else { return false }
        return true
    }
}
