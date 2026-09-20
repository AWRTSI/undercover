import Foundation

/// Conteneur de dépendances simple, injecté dans l'environnement SwiftUI, pour permettre de
/// substituer facilement le service de marché (mock aujourd'hui, API réelle demain) sans
/// toucher aux ViewModels.
@MainActor
final class AppDependencies: ObservableObject {
    /// `private(set)` plutôt que `let` : le service de marché démarre sur le mock, puis bascule
    /// vers `RemoteMarketDataService` une fois l'URL du scraper lue depuis les Réglages
    /// persistés (voir `FUTMarketWatchApp.bootstrapDefaultSettingsIfNeeded`). Les ViewModels
    /// lisent `dependencies.marketDataService` à chaque appel plutôt que de le capturer une
    /// fois, donc ce changement s'applique sans qu'ils aient besoin d'être recréés.
    private(set) var marketDataService: MarketDataServiceProtocol
    let detectionEngine: OpportunityDetectionEngine
    let notificationService: NotificationService

    init(
        marketDataService: MarketDataServiceProtocol = MockMarketDataService(),
        detectionEngine: OpportunityDetectionEngine = OpportunityDetectionEngine(),
        notificationService: NotificationService = .shared
    ) {
        self.marketDataService = marketDataService
        self.detectionEngine = detectionEngine
        self.notificationService = notificationService
    }

    func useRemoteMarketData(baseURL: URL) {
        marketDataService = RemoteMarketDataService(baseURL: baseURL)
    }

    func useMockMarketData() {
        marketDataService = MockMarketDataService()
    }
}
