import Foundation

/// Expose l'état des permissions de notification et les préférences de filtrage à la vue Réglages.
@MainActor
final class SettingsViewModel: ObservableObject {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var notificationService: NotificationService { dependencies.notificationService }

    func requestNotificationPermission() async {
        await dependencies.notificationService.requestAuthorizationIfNeeded()
    }

    func refreshNotificationStatus() async {
        await dependencies.notificationService.refreshAuthorizationStatus()
    }
}
