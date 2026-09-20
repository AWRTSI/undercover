import SwiftUI

/// Écran Marché : liste complète et consultable des cartes suivies par le moteur d'analyse,
/// avec recherche par nom/club/nation/ligue et tri. Rend visible ce que l'app scanne en
/// continu, en complément du résumé du Dashboard qui ne montre que le top des opportunités.
struct MarketView: View {
    @StateObject private var viewModel: MarketViewModel

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: MarketViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredAndSortedPlayers) { player in
                    MarketPlayerRow(player: player)
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchText, prompt: "Joueur, club, nation, ligue…")
            .navigationTitle("Marché")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Trier par", selection: $viewModel.sortOption) {
                            ForEach(MarketViewModel.SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .overlay {
                if viewModel.isSearchingRemotely {
                    ProgressView("Recherche sur le marché…")
                } else if viewModel.filteredAndSortedPlayers.isEmpty && viewModel.lastRemoteSearchFoundNothing {
                    ContentUnavailableView(
                        "Aucune carte trouvée",
                        systemImage: "magnifyingglass",
                        description: Text("Ni dans les cartes déjà suivies, ni dans une recherche élargie sur la source de données.")
                    )
                } else if viewModel.filteredAndSortedPlayers.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .task {
                await viewModel.loadInitialData()
                viewModel.startObservingLiveUpdates()
            }
            .onDisappear { viewModel.stopObservingLiveUpdates() }
            .onChange(of: viewModel.searchText) {
                viewModel.searchTextDidChange()
            }
        }
    }
}

private struct MarketPlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.headline)
                Text("\(player.club) · \(player.nation) · \(player.overall) OVR · \(player.rarity.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(player.currentPrice.coinsFormatted)
                    .font(.subheadline.weight(.semibold))
                Text(player.priceDeviation.signedPercentFormatted)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(player.priceDeviation < 0 ? .green : (player.priceDeviation > 0 ? .red : .secondary))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MarketView(dependencies: AppDependencies())
}
