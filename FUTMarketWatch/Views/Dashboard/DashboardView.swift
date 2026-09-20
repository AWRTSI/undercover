import SwiftUI

/// Tableau de bord : résumé des meilleures opportunités du moment et tendances globales du marché.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    trendsSection
                    opportunitiesSection
                }
                .padding()
            }
            .navigationTitle("Tableau de bord")
            .refreshable { await viewModel.loadInitialData() }
            .task {
                await viewModel.loadInitialData()
                viewModel.startObservingLiveUpdates()
            }
            .onDisappear { viewModel.stopObservingLiveUpdates() }
        }
    }

    private var trendsSection: some View {
        HStack(spacing: 12) {
            StatTile(title: "Cartes suivies", value: "\(viewModel.totalMarketCards)")
            StatTile(title: "En hausse", value: "\(viewModel.risingCount)", tint: .green)
            StatTile(title: "En baisse", value: "\(viewModel.fallingCount)", tint: .red)
        }
    }

    @ViewBuilder
    private var opportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meilleures opportunités")
                .font(.title3.weight(.bold))

            if viewModel.isLoading && viewModel.topOpportunities.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            } else if viewModel.topOpportunities.isEmpty {
                Text("Aucune opportunité détectée pour le moment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.topOpportunities) { alert in
                    OpportunityCardView(alert: alert)
                }
            }
        }
    }
}

#Preview {
    DashboardView(dependencies: AppDependencies())
}
