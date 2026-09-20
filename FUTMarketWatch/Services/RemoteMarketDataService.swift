import Foundation

/// Implémentation réseau de `MarketDataServiceProtocol`, branchée sur le service de scraping
/// FUTBIN (voir `scraper-service/` à la racine du dépôt). FUTBIN n'a pas d'API publique — ce
/// service tiers charge ses pages avec un vrai navigateur headless et expose les prix de
/// référence en JSON ; cette classe consomme ce JSON et le transforme en `Player`.
///
/// Important : EA fait coexister un marché "Console" (PS5/Xbox, prix partagés) et un marché PC
/// distinct. Le scraper renvoie les deux ; on privilégie le prix Console (PS5) par défaut,
/// avec repli sur le prix PC si la carte n'a pas de prix Console au moment du scrape.
///
/// Limite connue : FUTBIN affiche un prix de référence agrégé, pas des annonces individuelles
/// du marché EA — donc pas de vrai "sniping" d'annonce précise, seulement du suivi de tendance
/// et de dynamique de prix dans le temps (voir `OpportunityDetectionEngine`).
actor RemoteMarketDataService: MarketDataServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    /// Le scraper identifie chaque carte par un ID FUTBIN (string) ; l'app utilise des UUID
    /// partout ailleurs. On dérive un UUID stable à partir de cet ID (voir `UUID.init(deterministicFrom:)`)
    /// et on garde cette table pour retrouver l'ID d'origine (ex. pour l'historique détaillé).
    private var sourceIDByUUID: [UUID: String] = [:]

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchMarketSnapshot() async throws -> [Player] {
        let url = baseURL.appendingPathComponent("players")
        let (data, response) = try await session.data(from: url)
        try Self.validate(response)
        return try mapPlayers(from: data)
    }

    /// Interroge la recherche FUTBIN à la demande (voir `GET /search` côté scraper) plutôt que
    /// le sous-ensemble déjà suivi en continu — seule façon de trouver une carte qui n'est pas
    /// dans les quelques centaines pré-scrapées.
    func searchPlayers(query: String) async throws -> [Player] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return try await fetchMarketSnapshot() }

        guard var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false) else {
            throw MarketDataError.unknown
        }
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components.url else { throw MarketDataError.unknown }

        let (data, response) = try await session.data(from: url)
        try Self.validate(response)
        return try mapPlayers(from: data)
    }

    /// Partagé par `fetchMarketSnapshot` et `searchPlayers` : les deux endpoints du scraper
    /// renvoient exactement la même forme JSON (`{ players: [...] }`).
    private func mapPlayers(from data: Data) throws -> [Player] {
        let decoded: ScrapedPlayersResponse
        do {
            decoded = try JSONDecoder().decode(ScrapedPlayersResponse.self, from: data)
        } catch {
            throw MarketDataError.decoding(underlying: error)
        }

        return decoded.players.compactMap { scraped in
            guard let price = scraped.pricePS ?? scraped.pricePC else { return nil }

            let uuid = UUID(deterministicFrom: "futbin-\(scraped.id)")
            sourceIDByUUID[uuid] = scraped.id

            let history = (scraped.history ?? []).map { $0.asPricePoint }

            return Player(
                id: uuid,
                name: scraped.name,
                club: "Inconnu",
                nation: "Inconnu",
                league: "Inconnu",
                position: PlayerPosition(futbinCode: scraped.position),
                overall: scraped.overall,
                rarity: Rarity(futbinCardType: scraped.rarity),
                imageURL: nil,
                currentPrice: price,
                rollingAveragePrice: scraped.rollingAveragePrice ?? price,
                priceHistory: history
            )
        }
    }

    func fetchPriceHistory(for playerID: UUID, since: Date) async throws -> [PricePoint] {
        guard let sourceID = sourceIDByUUID[playerID] else { return [] }
        let url = baseURL.appendingPathComponent("players/\(sourceID)/history")
        let (data, response) = try await session.data(from: url)
        try Self.validate(response)

        let decoded: ScrapedHistoryResponse
        do {
            decoded = try JSONDecoder().decode(ScrapedHistoryResponse.self, from: data)
        } catch {
            throw MarketDataError.decoding(underlying: error)
        }
        return decoded.history.map { $0.asPricePoint }.filter { $0.timestamp >= since }
    }

    /// Le service de scraping ne couvre pas les SBC/objectifs (aucune source publique fiable
    /// identifiée pour ces données) : on reste sur le mock pour cette partie en attendant mieux.
    func fetchActiveSBCs() async throws -> [SBCRequirement] {
        MockData.activeSBCs
    }

    /// Contrairement au mock (qui simule une fluctuation par seconde pour "faire vivant"), une
    /// vraie source scrapée ne change vraiment que toutes les ~20 minutes (fraîcheur gérée côté
    /// serveur). On revérifie toutes les 5 minutes et on republie l'ensemble du marché à chaque
    /// fois plutôt qu'une carte au hasard.
    nonisolated func priceUpdatesStream() -> AsyncStream<Player> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000_000)
                    guard !Task.isCancelled, let players = try? await self.fetchMarketSnapshot() else { continue }
                    for player in players {
                        continuation.yield(player)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw MarketDataError.unknown }
        guard http.statusCode != 401 else { throw MarketDataError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw MarketDataError.unknown }
    }
}

/// Formes JSON exactes renvoyées par `scraper-service/server.js` — garder synchronisé si le
/// contrat du serveur change.
private struct ScrapedPlayersResponse: Decodable {
    let lastScrapedAt: Double?
    let players: [ScrapedPlayer]
}

private struct ScrapedPlayer: Decodable {
    let id: String
    let name: String
    let overall: Int
    let rarity: String
    let position: String
    let pricePS: Int?
    let pricePC: Int?
    let rollingAveragePrice: Int?
    let history: [ScrapedPricePoint]?
}

private struct ScrapedHistoryResponse: Decodable {
    let id: String
    let history: [ScrapedPricePoint]
}

private struct ScrapedPricePoint: Decodable {
    /// Millisecondes depuis epoch (`Date.now()` côté Node), pas des secondes.
    let timestamp: Double
    let price: Int

    var asPricePoint: PricePoint {
        PricePoint(timestamp: Date(timeIntervalSince1970: timestamp / 1000), price: price)
    }
}
