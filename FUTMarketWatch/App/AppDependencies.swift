import Foundation

/// Conteneur de dépendances simple, injecté dans l'environnement SwiftUI, pour permettre de
/// substituer facilement le service de marché (mock aujourd'hui, API réelle demain) sans
/// toucher aux ViewModels.
@MainActor
final class AppDependencies: ObservableObject {
    let marketDataService: MarketDataServiceProtocol
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
}
