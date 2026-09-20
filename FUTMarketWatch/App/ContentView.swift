import SwiftUI

/// Racine de navigation : tableau de bord, filons, watchlist/portefeuille, outils et réglages.
struct ContentView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        TabView {
            DashboardView(dependencies: dependencies)
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }

            AlertsView(dependencies: dependencies)
                .tabItem { Label("Filons", systemImage: "bell.badge.fill") }

            WatchlistView(dependencies: dependencies)
                .tabItem { Label("Watchlist", systemImage: "eye.fill") }

            PortfolioView(dependencies: dependencies)
                .tabItem { Label("Portefeuille", systemImage: "briefcase.fill") }

            TaxCalculatorView()
                .tabItem { Label("Calculateur", systemImage: "percent") }

            SettingsView(dependencies: dependencies)
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDependencies())
        .modelContainer(for: [WatchlistItem.self, HoldingPosition.self, Transaction.self, UserFilterSettings.self], inMemory: true)
}
