import Foundation

/// Alimente l'écran Marché : liste complète des cartes suivies par le moteur, avec recherche
/// et tri, pour que l'utilisateur voie concrètement ce que l'app scanne en continu (et pas
/// seulement le résumé des meilleures opportunités du Dashboard).
@MainActor
final class MarketViewModel: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .deviationAscending
    @Published private(set) var isSearchingRemotely = false
    @Published private(set) var lastRemoteSearchFoundNothing = false

    enum SortOption: String, CaseIterable, Identifiable {
        case deviationAscending = "Plus sous-évaluées"
        case priceAscending = "Prix croissant"
        case priceDescending = "Prix décroissant"
        case name = "Nom (A-Z)"
        var id: String { rawValue }
    }

    private let dependencies: AppDependencies
    private var streamTask: Task<Void, Never>?
    private var remoteSearchTask: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var filteredAndSortedPlayers: [Player] {
        let filtered = searchText.isEmpty
            ? players
            : players.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.club.localizedCaseInsensitiveContains(searchText) ||
                $0.nation.localizedCaseInsensitiveContains(searchText) ||
                $0.league.localizedCaseInsensitiveContains(searchText)
            }

        switch sortOption {
        case .deviationAscending: return filtered.sorted { $0.priceDeviation < $1.priceDeviation }
        case .priceAscending: return filtered.sorted { $0.currentPrice < $1.currentPrice }
        case .priceDescending: return filtered.sorted { $0.currentPrice > $1.currentPrice }
        case .name: return filtered.sorted { $0.name < $1.name }
        }
    }

    func loadInitialData() async {
        guard let fetched = try? await dependencies.marketDataService.fetchMarketSnapshot() else { return }
        players = fetched
    }

    func startObservingLiveUpdates() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await updated in dependencies.marketDataService.priceUpdatesStream() {
                guard !Task.isCancelled else { break }
                if let index = players.firstIndex(where: { $0.id == updated.id }) {
                    players[index] = updated
                }
            }
        }
    }

    func stopObservingLiveUpdates() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Déclenché quand `searchText` change. Le filtre local (`filteredAndSortedPlayers`) ne
    /// porte que sur ce qui est déjà chargé — un catalogue réel (FUTBIN) en compte des dizaines
    /// de milliers, bien plus que ce qui est suivi en continu. Si rien ne correspond localement,
    /// on tente une recherche à distance après un court délai (pas à chaque frappe).
    func searchTextDidChange() {
        remoteSearchTask?.cancel()
        lastRemoteSearchFoundNothing = false

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3, filteredAndSortedPlayers.isEmpty else { return }

        remoteSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }

            isSearchingRemotely = true
            defer { isSearchingRemotely = false }

            guard let results = try? await dependencies.marketDataService.searchPlayers(query: query),
                  !Task.isCancelled else { return }

            var didAddAny = false
            for result in results where !players.contains(where: { $0.id == result.id }) {
                players.append(result)
                didAddAny = true
            }
            lastRemoteSearchFoundNothing = !didAddAny
        }
    }
}
