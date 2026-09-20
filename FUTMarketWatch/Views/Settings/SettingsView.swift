import SwiftUI
import SwiftData

/// Réglages : permissions de notifications et filtres configurables (budget, bénéfice minimum,
/// niveau de risque et types d'investissement pris en compte par le moteur de détection).
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Query private var filterSettingsList: [UserFilterSettings]

    /// Repli en mémoire, jamais inséré dans SwiftData. La ligne persistée réelle est créée une
    /// seule fois au lancement de l'app (voir `FUTMarketWatchApp.bootstrapDefaultSettingsIfNeeded`).
    /// Auparavant, chaque Stepper/Toggle de cet écran appelait indépendamment une propriété
    /// calculée qui insérait un NOUVEL objet à chaque accès tant que `@Query` n'avait pas
    /// rafraîchi sa liste : un seul rendu pouvait ainsi créer jusqu'à 8 lignes en double, et
    /// chaque réglage écrivait sur un objet différent aussitôt jeté — les valeurs ne
    /// persistaient jamais vraiment. D'où les plantages et réglages qui ne "prenaient" pas.
    @State private var localFallback = UserFilterSettings()
    @State private var apiURLDraft: String = ""
    @State private var apiURLFeedback: String?
    @State private var hasLoadedDraft = false

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(dependencies: dependencies))
    }

    private var filterSettings: UserFilterSettings {
        filterSettingsList.first ?? localFallback
    }

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                dataSourceSection
                platformSection
                budgetSection
                riskSection
                typesSection
            }
            .navigationTitle("Réglages")
            .task {
                await viewModel.refreshNotificationStatus()
                if !hasLoadedDraft {
                    apiURLDraft = filterSettings.apiBaseURLString
                    hasLoadedDraft = true
                }
            }
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

    private var dataSourceSection: some View {
        Section {
            TextField("https://ton-service.onrender.com", text: $apiURLDraft)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Appliquer") {
                switch viewModel.applyMarketDataSource(urlString: apiURLDraft) {
                case .appliedRemote:
                    filterSettings.apiBaseURLString = apiURLDraft.trimmingCharacters(in: .whitespaces)
                    apiURLFeedback = "Connecté au service de scraping FUTBIN."
                case .appliedMock:
                    filterSettings.apiBaseURLString = ""
                    apiURLFeedback = "Retour aux données simulées (mock)."
                case .invalidURL:
                    apiURLFeedback = "URL invalide — vérifie qu'elle commence par https://"
                }
            }
            if let apiURLFeedback {
                Text(apiURLFeedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Source de données")
        } footer: {
            Text("Laisse vide pour rester sur les données simulées. Colle ici l'URL Render de ton service de scraping FUTBIN (dossier scraper-service/) pour passer sur de vrais prix de référence FC 27.")
        }
    }

    private var platformSection: some View {
        Section {
            Picker("Marché", selection: Binding(
                get: { filterSettings.platform },
                set: { filterSettings.platform = $0 }
            )) {
                ForEach(GamingPlatform.allCases) { platform in
                    Text(platform.rawValue).tag(platform)
                }
            }
        } footer: {
            Text("EA sépare le marché Console (PS5/Xbox, mêmes prix) du marché PC. Le service de scraping renvoie les deux prix ; l'app utilise actuellement le prix Console (PS5) en priorité quel que soit ce réglage — le brancher dynamiquement sur ce choix est une amélioration à venir.")
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
