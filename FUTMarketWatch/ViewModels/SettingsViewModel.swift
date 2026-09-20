import Foundation

/// Expose l'état des permissions de notification et les préférences de filtrage à la vue Réglages.
@MainActor
final class SettingsViewModel: ObservableObject {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var notificationService: NotificationService { dependencies.notificationService }

    func requestNotificationPermission() async {
        await dependencies.notificationService.requestAuthorizationIfNeeded()
    }

    func refreshNotificationStatus() async {
        await dependencies.notificationService.refreshAuthorizationStatus()
    }

    enum MarketSourceUpdateResult {
        case appliedRemote
        case appliedMock
        case invalidURL
    }

    /// Applique immédiatement la source de données choisie, sans attendre le prochain lancement
    /// de l'app (le bootstrap au démarrage ne s'exécute qu'une fois). Une URL vide repasse sur
    /// le mock ; une URL non vide mais invalide est signalée plutôt qu'ignorée en silence.
    func applyMarketDataSource(urlString: String) -> MarketSourceUpdateResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            dependencies.useMockMarketData()
            return .appliedMock
        }
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            return .invalidURL
        }
        dependencies.useRemoteMarketData(baseURL: url)
        return .appliedRemote
    }
}
