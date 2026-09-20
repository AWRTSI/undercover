# FUT Market Watch

App iOS native (Swift/SwiftUI, MVVM) d'analyse du marché des transferts et de notifications
d'opportunités d'achat/revente. Voir le cahier des charges dans la conversation d'origine.

## Ouvrir le projet

Le code a été généré sur une machine sans Xcode ; il n'y a donc pas de `.xcodeproj` prêt à
l'emploi. Sur un Mac avec Xcode 15+ :

```bash
brew install xcodegen
cd FUTMarketWatch
xcodegen generate
open FUTMarketWatch.xcodeproj
```

Cible : iOS 17+. Aucune dépendance externe (SwiftUI, Combine, Swift Charts, SwiftData,
UserNotifications — tous frameworks Apple).

## Structure

- `Models/` — `Player`, `MarketAlert`, `SBCRequirement`, modèles SwiftData (`WatchlistItem`,
  `HoldingPosition`, `Transaction`, `UserFilterSettings`).
- `Services/` — `MarketDataServiceProtocol` (abstraction API), `MockMarketDataService` (données
  factices utilisées par défaut), `RemoteMarketDataService` (squelette REST/WebSocket à activer
  avec une vraie API), `OpportunityDetectionEngine` (sniping, tendances), `SBCPredictionService`,
  `TaxCalculator`, `NotificationService`.
- `ViewModels/` — un ViewModel par écran, MVVM.
- `Views/` — Dashboard, Filons (centre de notifications), Watchlist, Portefeuille, Calculateur
  de taxe, Réglages.

## Brancher une vraie API

Remplacer `MockMarketDataService()` par `RemoteMarketDataService(baseURL:)` dans
`App/AppDependencies.swift`.
