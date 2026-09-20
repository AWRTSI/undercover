import SwiftUI
import SwiftData

/// Centre de notifications : flux en temps réel des alertes émises par l'algorithme,
/// filtrable par type et respectant les préférences utilisateur (budget, marge minimum, risque).
struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel
    @Query private var filterSettingsList: [UserFilterSettings]
    @Environment(\.modelContext) private var modelContext

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: AlertsViewModel(dependencies: dependencies))
    }

    private var filterSettings: UserFilterSettings {
        if let existing = filterSettingsList.first { return existing }
        let created = UserFilterSettings()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeFilterBar

                if viewModel.filteredFeed.isEmpty {
                    ContentUnavailableView(
                        "Aucun filon pour l'instant",
                        systemImage: "bell.slash",
                        description: Text("Les opportunités correspondant à vos filtres apparaîtront ici en temps réel.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredFeed) { alert in
                                OpportunityCardView(alert: alert)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Filons")
            .task {
                await viewModel.start(filterSettings: filterSettings)
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Tous", isSelected: viewModel.selectedTypeFilter == nil) {
                    viewModel.selectedTypeFilter = nil
                }
                ForEach(AlertType.allCases) { type in
                    filterChip(title: type.rawValue, isSelected: viewModel.selectedTypeFilter == type) {
                        viewModel.selectedTypeFilter = type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AlertsView(dependencies: AppDependencies())
        .modelContainer(for: UserFilterSettings.self, inMemory: true)
}
