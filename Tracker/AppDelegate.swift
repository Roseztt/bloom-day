import UIKit
import UserNotifications

/// Owns the notification delegate so taps and action buttons still work when the
/// app was launched straight from a notification.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        return true
    }

    /// Show reminders even while the user is looking at the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskID = response.notification.request.content.userInfo[NotificationManager.taskIDKey] as? String
        let action = response.actionIdentifier

        Task { @MainActor in
            switch action {
            case NotificationManager.completeActionID:
                if let taskID {
                    DataController.shared.completeTask(uid: taskID)
                }
            case NotificationManager.snoozeActionID:
                if let taskID {
                    DataController.shared.snoozeTask(uid: taskID, hours: SettingsStore.shared.snoozeHours)
                }
            default:
                break
            }

            NotificationManager.shared.refreshSchedule()
            completionHandler()
        }
    }
}
