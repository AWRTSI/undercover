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
  factices utilisées par défaut), `RemoteMarketDataService` (branché sur `scraper-service/`,
  actif dès qu'une URL est configurée dans Réglages), `OpportunityDetectionEngine` (sniping,
  tendances, investissement), `SBCPredictionService`, `TaxCalculator`, `NotificationService`.
- `ViewModels/` — un ViewModel par écran, MVVM.
- `Views/` — Dashboard, Filons (centre de notifications), Watchlist, Portefeuille, Calculateur
  de taxe, Réglages.

## Brancher une vraie source de prix (FUTBIN)

FUTBIN n'a pas d'API publique (403 sur un fetch basique — testé) ; le dossier
[`scraper-service/`](../scraper-service) contient un petit serveur Node.js/Playwright qui
charge ses pages avec un vrai navigateur headless et expose les prix de référence FC 27 en
JSON. Voir son propre README pour le déployer (gratuit sur Render).

Une fois déployé, colle l'URL du service dans Réglages → Source de données, dans l'app — pas
besoin de recompiler. `RemoteMarketDataService.swift` bascule automatiquement dessus.

Limite à connaître : FUTBIN affiche un prix de référence agrégé, pas des annonces individuelles
du marché EA — donc pas de vrai "sniping" d'annonce précise, seulement du suivi de tendance et
de dynamique de prix dans le temps (catégories Tendance/Investissement).
