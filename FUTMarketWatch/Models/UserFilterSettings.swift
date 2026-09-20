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

    init(
        availableBudget: Int = 100_000,
        minimumNetProfit: Int = 500,
        minimumMarginPercent: Double = 0.08,
        maxRiskLevel: RiskLevel = .medium,
        enabledAlertTypes: [AlertType] = AlertType.allCases
    ) {
        self.availableBudget = availableBudget
        self.minimumNetProfit = minimumNetProfit
        self.minimumMarginPercent = minimumMarginPercent
        self.maxRiskLevelRaw = maxRiskLevel.rawValue
        self.enabledAlertTypesRaw = enabledAlertTypes.map(\.rawValue)
    }

    var maxRiskLevel: RiskLevel {
        get { RiskLevel(rawValue: maxRiskLevelRaw) ?? .medium }
        set { maxRiskLevelRaw = newValue.rawValue }
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
