import Foundation

/// Alimente le tableau de bord : meilleures opportunités du moment et tendances globales.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var topOpportunities: [MarketAlert] = []
    @Published private(set) var players: [Player] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dependencies: AppDependencies
    private var streamTask: Task<Void, Never>?

    var totalMarketCards: Int { players.count }
    var risingCount: Int { players.filter { $0.priceDeviation > 0.05 }.count }
    var fallingCount: Int { players.filter { $0.priceDeviation < -0.05 }.count }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let playersResult = dependencies.marketDataService.fetchMarketSnapshot()
            async let sbcsResult = dependencies.marketDataService.fetchActiveSBCs()
            let (fetchedPlayers, sbcs) = try await (playersResult, sbcsResult)
            players = fetchedPlayers
            recomputeOpportunities(sbcs: sbcs)
        } catch {
            errorMessage = (error as? MarketDataError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// S'abonne au flux de prix temps réel et recalcule les opportunités à chaque mise à jour.
    func startObservingLiveUpdates() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await updatedPlayer in dependencies.marketDataService.priceUpdatesStream() {
                guard !Task.isCancelled else { break }
                if let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) {
                    players[index] = updatedPlayer
                }
                if let sbcs = try? await dependencies.marketDataService.fetchActiveSBCs() {
                    recomputeOpportunities(sbcs: sbcs)
                }
            }
        }
    }

    func stopObservingLiveUpdates() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func recomputeOpportunities(sbcs: [SBCRequirement]) {
        let all = dependencies.detectionEngine.detectOpportunities(players: players, sbcs: sbcs)
        topOpportunities = Array(all.prefix(10))
    }
}
