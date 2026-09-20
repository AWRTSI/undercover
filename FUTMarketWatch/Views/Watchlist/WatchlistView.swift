import SwiftUI
import SwiftData

/// Gestionnaire de watchlist : cartes suivies par l'utilisateur avec prix cible, et indicateur
/// visuel lorsque le prix marché atteint la cible d'achat.
struct WatchlistView: View {
    @StateObject private var viewModel: WatchlistViewModel
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Watchlist vide",
                        systemImage: "eye.slash",
                        description: Text("Ajoutez des cartes à surveiller pour être alerté quand elles atteignent votre prix cible.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            WatchlistRow(
                                item: item,
                                marketPrice: viewModel.marketPrice(for: item),
                                reachedTarget: viewModel.hasReachedTarget(item)
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet { viewModel.remove(items[index], context: modelContext) }
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddToWatchlistSheet(viewModel: viewModel)
            }
            .task { await viewModel.refreshMarketPrices() }
            .refreshable { await viewModel.refreshMarketPrices() }
        }
    }
}

private struct WatchlistRow: View {
    let item: WatchlistItem
    let marketPrice: Int?
    let reachedTarget: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.playerName).font(.headline)
                Text("\(item.club) · \(item.overall) OVR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Cible \(item.targetBuyPrice.coinsFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let marketPrice {
                    Text(marketPrice.coinsFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(reachedTarget ? .green : .primary)
                }
            }
            if reachedTarget {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddToWatchlistSheet: View {
    @ObservedObject var viewModel: WatchlistViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlayer: Player?
    @State private var targetPrice: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Joueur") {
                    Picker("Carte", selection: $selectedPlayer) {
                        Text("Sélectionner").tag(Player?.none)
                        ForEach(MockData.players) { player in
                            Text("\(player.name) (\(player.overall) OVR)").tag(Player?.some(player))
                        }
                    }
                }
                Section("Prix cible d'achat") {
                    TextField("Ex. 2 400 000", text: $targetPrice)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Ajouter à la watchlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        guard let player = selectedPlayer, let price = Int(targetPrice) else { return }
                        viewModel.addToWatchlist(player: player, targetBuyPrice: price, context: modelContext)
                        dismiss()
                    }
                    .disabled(selectedPlayer == nil || Int(targetPrice) == nil)
                }
            }
        }
    }
}

#Preview {
    WatchlistView(dependencies: AppDependencies())
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
