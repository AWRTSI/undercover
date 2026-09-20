import Foundation
import SwiftData

/// Alimente le centre de notifications : flux temps réel des alertes filtrées selon les
/// préférences de l'utilisateur (budget, bénéfice minimum, risque, types d'investissement).
@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var feed: [MarketAlert] = []
    @Published var selectedTypeFilter: AlertType?

    private let dependencies: AppDependencies
    private var streamTask: Task<Void, Never>?
    private var lastKnownSBCs: [SBCRequirement] = []
    private var notifiedAlertIDs = Set<String>()

    var filteredFeed: [MarketAlert] {
        guard let filter = selectedTypeFilter else { return feed }
        return feed.filter { $0.type == filter }
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start(filterSettings: UserFilterSettings) async {
        var latestPlayers: [UUID: Player] = [:]
        do {
            let players = try await dependencies.marketDataService.fetchMarketSnapshot()
            latestPlayers = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            lastKnownSBCs = try await dependencies.marketDataService.fetchActiveSBCs()
            evaluateAndPublish(players: players, filterSettings: filterSettings)
        } catch {
            // Le tableau de bord affiche déjà l'erreur réseau ; le centre d'alertes reste silencieux ici.
        }

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await updated in dependencies.marketDataService.priceUpdatesStream() {
                guard !Task.isCancelled else { break }
                latestPlayers[updated.id] = updated
                evaluateAndPublish(players: Array(latestPlayers.values), filterSettings: filterSettings)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func evaluateAndPublish(players: [Player], filterSettings: UserFilterSettings) {
        let detected = dependencies.detectionEngine.detectOpportunities(players: players, sbcs: lastKnownSBCs)
        let accepted = detected.filter(filterSettings.accepts)

        feed = accepted.sorted { $0.detectedAt > $1.detectedAt }

        for alert in accepted where !notifiedAlertIDs.contains(alert.id.uuidString) {
            notifiedAlertIDs.insert(alert.id.uuidString)
            dependencies.notificationService.scheduleOpportunityNotification(for: alert)
        }
    }
}
