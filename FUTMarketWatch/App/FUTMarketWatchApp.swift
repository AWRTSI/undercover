import SwiftUI
import SwiftData

@main
struct FUTMarketWatchApp: App {
    @StateObject private var dependencies = AppDependencies()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WatchlistItem.self,
            HoldingPosition.self,
            Transaction.self,
            UserFilterSettings.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossible d'initialiser le conteneur SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
                .task {
                    bootstrapDefaultSettingsIfNeeded()
                    applyConfiguredMarketDataSource()
                    await dependencies.notificationService.requestAuthorizationIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Garantit qu'une unique ligne `UserFilterSettings` existe, une seule fois au lancement.
    /// Fait exprès ici plutôt que dans les vues : insérer un modèle depuis une propriété calculée
    /// lue pendant le rendu (`body`) déclenche des ré-évaluations en boucle et des écritures
    /// SwiftData concurrentes qui provoquaient des plantages/comportements imprévisibles.
    @MainActor
    private func bootstrapDefaultSettingsIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<UserFilterSettings>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }
        context.insert(UserFilterSettings())
        try? context.save()
    }

    /// Bascule vers le vrai service de scraping FUTBIN si une URL a été configurée dans les
    /// Réglages ; sinon reste sur les données simulées (comportement par défaut).
    @MainActor
    private func applyConfiguredMarketDataSource() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<UserFilterSettings>()
        guard let settings = try? context.fetch(descriptor).first else { return }
        let trimmed = settings.apiBaseURLString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }
        dependencies.useRemoteMarketData(baseURL: url)
    }
}
