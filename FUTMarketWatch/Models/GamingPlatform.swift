import Foundation

/// Plateforme dont doit provenir le prix de marché. EA sépare l'économie du jeu en deux
/// marchés distincts : un marché "Console" partagé entre PlayStation et Xbox (mêmes prix des
/// deux côtés depuis l'unification de l'écosystème EA), et un marché PC séparé, dont les prix
/// peuvent nettement diverger du marché console.
enum GamingPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case console = "PS5 / Xbox (Console)"
    case pc = "PC"

    var id: String { rawValue }
}
