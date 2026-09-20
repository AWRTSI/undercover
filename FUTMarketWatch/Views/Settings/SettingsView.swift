import SwiftUI
import SwiftData

/// Réglages : permissions de notifications et filtres configurables (budget, bénéfice minimum,
/// niveau de risque et types d'investissement pris en compte par le moteur de détection).
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Query private var filterSettingsList: [UserFilterSettings]
    @Environment(\.modelContext) private var modelContext

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(dependencies: dependencies))
    }

    private var filterSettings: UserFilterSettings {
        if let existing = filterSettingsList.first { return existing }
        let created = UserFilterSettings()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                budgetSection
                riskSection
                typesSection
            }
            .navigationTitle("Réglages")
            .task { await viewModel.refreshNotificationStatus() }
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            HStack {
                Text("Statut")
                Spacer()
                Text(statusLabel)
                    .foregroundStyle(.secondary)
            }
            if viewModel.notificationService.authorizationStatus != .authorized {
                Button("Activer les notifications") {
                    Task { await viewModel.requestNotificationPermission() }
                }
            }
        }
    }

    private var statusLabel: String {
        switch viewModel.notificationService.authorizationStatus {
        case .authorized: return "Activées"
        case .denied: return "Refusées"
        case .notDetermined: return "Non configurées"
        case .provisional: return "Provisoires"
        case .ephemeral: return "Temporaires"
        @unknown default: return "Inconnu"
        }
    }

    private var budgetSection: some View {
        Section("Budget & rentabilité") {
            Stepper(value: Binding(
                get: { filterSettings.availableBudget },
                set: { filterSettings.availableBudget = $0 }
            ), in: 0...10_000_000, step: 5_000) {
                LabeledContent("Budget disponible", value: filterSettings.availableBudget.coinsFormatted)
            }
            Stepper(value: Binding(
                get: { filterSettings.minimumNetProfit },
                set: { filterSettings.minimumNetProfit = $0 }
            ), in: 0...100_000, step: 500) {
                LabeledContent("Bénéfice net minimum", value: filterSettings.minimumNetProfit.coinsFormatted)
            }
            Stepper(value: Binding(
                get: { filterSettings.minimumMarginPercent * 100 },
                set: { filterSettings.minimumMarginPercent = $0 / 100 }
            ), in: 0...50, step: 1) {
                LabeledContent("Marge minimum", value: filterSettings.minimumMarginPercent.signedPercentFormatted)
            }
        }
    }

    private var riskSection: some View {
        Section("Risque maximum accepté") {
            Picker("Risque", selection: Binding(
                get: { filterSettings.maxRiskLevel },
                set: { filterSettings.maxRiskLevel = $0 }
            )) {
                ForEach(RiskLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var typesSection: some View {
        Section("Types d'opportunités") {
            ForEach(AlertType.allCases) { type in
                Toggle(type.rawValue, isOn: Binding(
                    get: { filterSettings.enabledAlertTypes.contains(type) },
                    set: { isOn in
                        var current = filterSettings.enabledAlertTypes
                        if isOn { current.insert(type) } else { current.remove(type) }
                        filterSettings.enabledAlertTypes = current
                    }
                ))
            }
        }
    }
}

#Preview {
    SettingsView(dependencies: AppDependencies())
        .modelContainer(for: UserFilterSettings.self, inMemory: true)
}
