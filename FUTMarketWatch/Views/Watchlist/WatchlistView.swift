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
                                reachedTarget: viewModel.hasReachedTarget(item),
                                isTrackedLive: viewModel.isTrackedLive(item)
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
    let isTrackedLive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.playerName).font(.headline)
                Text("\(item.club) · \(item.overall) OVR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !isTrackedLive {
                    Label("Suivi manuel — vérifie le prix en jeu", systemImage: "hand.tap")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
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

/// Deux façons d'ajouter une carte : la choisir dans le marché simulé (prix live disponible)
/// ou la saisir manuellement — indispensable puisque le catalogue mock ne contient qu'une
/// vingtaine de cartes alors que le jeu réel en compte des milliers.
private enum WatchlistEntryMode: String, CaseIterable, Identifiable {
    case market = "Depuis le marché"
    case manual = "Carte personnalisée"
    var id: String { rawValue }
}

private struct AddToWatchlistSheet: View {
    @ObservedObject var viewModel: WatchlistViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mode: WatchlistEntryMode = .market
    @State private var selectedPlayer: Player?
    @State private var targetPrice: String = ""

    @State private var manualName: String = ""
    @State private var manualClub: String = ""
    @State private var manualOverall: String = ""

    private var isValid: Bool {
        guard Int(targetPrice) != nil else { return false }
        switch mode {
        case .market:
            return selectedPlayer != nil
        case .manual:
            return !manualName.trimmingCharacters(in: .whitespaces).isEmpty && Int(manualOverall) != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(WatchlistEntryMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch mode {
                case .market:
                    Section("Joueur du marché simulé") {
                        Picker("Carte", selection: $selectedPlayer) {
                            Text("Sélectionner").tag(Player?.none)
                            ForEach(MockData.players) { player in
                                Text("\(player.name) (\(player.overall) OVR)").tag(Player?.some(player))
                            }
                        }
                    }
                case .manual:
                    Section("N'importe quelle carte") {
                        TextField("Nom du joueur", text: $manualName)
                        TextField("Club", text: $manualClub)
                        TextField("Note globale (OVR)", text: $manualOverall)
                            .keyboardType(.numberPad)
                    }
                    Text("Cette carte n'existe pas dans le marché simulé : pas de prix live, juste un rappel à ta cible d'achat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        guard let price = Int(targetPrice) else { return }
                        switch mode {
                        case .market:
                            guard let player = selectedPlayer else { return }
                            viewModel.addToWatchlist(player: player, targetBuyPrice: price, context: modelContext)
                        case .manual:
                            guard let overall = Int(manualOverall) else { return }
                            let club = manualClub.trimmingCharacters(in: .whitespaces)
                            viewModel.addManualEntry(
                                name: manualName.trimmingCharacters(in: .whitespaces),
                                club: club.isEmpty ? "Club inconnu" : club,
                                overall: overall,
                                targetBuyPrice: price,
                                context: modelContext
                            )
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview {
    WatchlistView(dependencies: AppDependencies())
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
