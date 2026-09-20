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
                    await dependencies.notificationService.requestAuthorizationIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
