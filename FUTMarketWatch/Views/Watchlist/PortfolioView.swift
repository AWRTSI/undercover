import SwiftUI
import SwiftData

/// Suivi du portefeuille : positions détenues, bénéfices/pertes latents et réalisés,
/// valeur globale du club/stock.
struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel
    @Query private var holdings: [HoldingPosition]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var showingBuySheet = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        StatTile(title: "Valeur nette du stock", value: viewModel.totalPortfolioValue(holdings: holdings).coinsFormatted)
                        StatTile(
                            title: "P&L latent",
                            value: signed(viewModel.totalUnrealizedProfit(holdings: holdings)),
                            tint: viewModel.totalUnrealizedProfit(holdings: holdings) >= 0 ? .green : .red
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
                .listRowSeparator(.hidden)

                Section("Positions détenues") {
                    if holdings.isEmpty {
                        Text("Aucune carte en portefeuille.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(holdings) { holding in
                            HoldingRow(holding: holding) {
                                viewModel.recordSale(holding: holding, sellPrice: holding.lastKnownMarketPrice, context: modelContext)
                            }
                        }
                    }
                }

                Section("Historique") {
                    if transactions.isEmpty {
                        Text("Aucune transaction enregistrée.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(transactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle("Portefeuille")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBuySheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingBuySheet) {
                RecordPurchaseSheet(viewModel: viewModel)
            }
            .task { await viewModel.refreshMarketPrices(holdings: holdings, context: modelContext) }
            .refreshable { await viewModel.refreshMarketPrices(holdings: holdings, context: modelContext) }
        }
    }

    private func signed(_ value: Int) -> String {
        (value >= 0 ? "+" : "") + value.coinsFormatted
    }
}

private struct HoldingRow: View {
    let holding: HoldingPosition
    let onSell: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.playerName).font(.headline)
                Text("Acheté \(holding.buyPrice.coinsFormatted) · Marché \(holding.lastKnownMarketPrice.coinsFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text((holding.unrealizedNetProfit >= 0 ? "+" : "") + holding.unrealizedNetProfit.coinsFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(holding.unrealizedNetProfit >= 0 ? .green : .red)
                Button("Vendre", action: onSell)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.side == .buy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(transaction.side == .buy ? .red : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.playerName).font(.subheadline)
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amount.coinsFormatted)
                .font(.subheadline.weight(.medium))
        }
    }
}

private enum PurchaseEntryMode: String, CaseIterable, Identifiable {
    case market = "Depuis le marché"
    case manual = "Carte personnalisée"
    var id: String { rawValue }
}

private struct RecordPurchaseSheet: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mode: PurchaseEntryMode = .market
    @State private var selectedPlayer: Player?
    @State private var buyPrice: String = ""

    @State private var manualName: String = ""
    @State private var manualClub: String = ""
    @State private var manualOverall: String = ""

    private var isValid: Bool {
        guard Int(buyPrice) != nil else { return false }
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
                        ForEach(PurchaseEntryMode.allCases) { mode in
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
                    Text("Cette carte n'existe pas dans le marché simulé : sa valeur ne sera pas mise à jour automatiquement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Prix d'achat") {
                    TextField("Ex. 2 400 000", text: $buyPrice)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Enregistrer un achat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        guard let price = Int(buyPrice) else { return }
                        switch mode {
                        case .market:
                            guard let player = selectedPlayer else { return }
                            viewModel.recordPurchase(player: player, buyPrice: price, context: modelContext)
                        case .manual:
                            guard let overall = Int(manualOverall) else { return }
                            let club = manualClub.trimmingCharacters(in: .whitespaces)
                            viewModel.recordManualPurchase(
                                name: manualName.trimmingCharacters(in: .whitespaces),
                                club: club.isEmpty ? "Club inconnu" : club,
                                overall: overall,
                                buyPrice: price,
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
    PortfolioView(dependencies: AppDependencies())
        .modelContainer(for: [HoldingPosition.self, Transaction.self], inMemory: true)
}
