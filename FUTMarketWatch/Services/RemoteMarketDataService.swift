import Foundation

/// Implémentation réseau de `MarketDataServiceProtocol` : REST pour les lectures ponctuelles
/// (snapshot, historique, SBCs) et WebSocket pour le flux de prix temps réel.
///
/// Squelette prêt à brancher sur une API de données de marché externe — non utilisé tant
/// qu'aucune URL de production n'est fournie. Remplacer `MockMarketDataService` par ce type
/// dans `AppDependencies` une fois l'API disponible.
final class RemoteMarketDataService: NSObject, MarketDataServiceProtocol {
    private let baseURL: URL
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchMarketSnapshot() async throws -> [Player] {
        try await get([Player].self, path: "market/snapshot")
    }

    func fetchPriceHistory(for playerID: UUID, since: Date) async throws -> [PricePoint] {
        let isoDate = ISO8601DateFormatter().string(from: since)
        return try await get([PricePoint].self, path: "market/players/\(playerID)/history?since=\(isoDate)")
    }

    func fetchActiveSBCs() async throws -> [SBCRequirement] {
        try await get([SBCRequirement].self, path: "sbc/active")
    }

    func priceUpdatesStream() -> AsyncStream<Player> {
        AsyncStream { continuation in
            let url = baseURL.appendingPathComponent("market/stream")
            let task = session.webSocketTask(with: url)
            webSocketTask = task
            task.resume()

            func listen() {
                task.receive { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(.data(let data)):
                        if let player = try? JSONDecoder.futMarket.decode(Player.self, from: data) {
                            continuation.yield(player)
                        }
                        listen()
                    case .success(.string(let text)):
                        if let data = text.data(using: .utf8),
                           let player = try? JSONDecoder.futMarket.decode(Player.self, from: data) {
                            continuation.yield(player)
                        }
                        listen()
                    case .success:
                        listen()
                    case .failure:
                        continuation.finish()
                    }
                }
            }
            listen()

            continuation.onTermination = { _ in
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func get<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw MarketDataError.unknown }
            guard http.statusCode != 401 else { throw MarketDataError.unauthorized }
            guard (200..<300).contains(http.statusCode) else { throw MarketDataError.unknown }
            do {
                return try JSONDecoder.futMarket.decode(T.self, from: data)
            } catch {
                throw MarketDataError.decoding(underlying: error)
            }
        } catch let error as MarketDataError {
            throw error
        } catch {
            throw MarketDataError.network(underlying: error)
        }
    }
}

extension JSONDecoder {
    static let futMarket: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
