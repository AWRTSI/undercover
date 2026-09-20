import Foundation
import UserNotifications

/// Encapsule `UNUserNotificationCenter` pour l'envoi d'alertes locales d'opportunités et la
/// gestion des permissions. Prêt à recevoir des notifications distantes (remote push) via
/// `registerForRemoteNotifications` côté AppDelegate/App si un backend push est ajouté plus tard.
@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Programme une notification locale immédiate pour une opportunité détectée.
    /// Le contenu inclut le joueur, le prix cible, le bénéfice net estimé et le niveau de risque,
    /// conformément au format attendu par le cahier des charges.
    func scheduleOpportunityNotification(for alert: MarketAlert) {
        guard authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(alert.type.rawValue) — \(alert.player.name)"
        content.body = Self.formatBody(for: alert)
        content.sound = .default
        content.userInfo = ["alertID": alert.id.uuidString]

        switch alert.riskLevel {
        case .low: content.interruptionLevel = .active
        case .medium: content.interruptionLevel = .active
        case .high: content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        center.add(request)
    }

    static func formatBody(for alert: MarketAlert) -> String {
        let currency = NumberFormatter.coins
        let buy = currency.string(from: NSNumber(value: alert.buyPrice)) ?? "\(alert.buyPrice)"
        let sell = currency.string(from: NSNumber(value: alert.estimatedSellPrice)) ?? "\(alert.estimatedSellPrice)"
        let profit = currency.string(from: NSNumber(value: alert.netProfit)) ?? "\(alert.netProfit)"
        return "Acheter à \(buy) · Revente estimée \(sell) · Bénéfice net \(profit) · Risque \(alert.riskLevel.rawValue)"
    }

    func removePendingNotification(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Affiche les notifications même si l'app est au premier plan, pour ne manquer aucune
    /// opportunité pendant que l'utilisateur consulte l'app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

extension NumberFormatter {
    static let coins: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
