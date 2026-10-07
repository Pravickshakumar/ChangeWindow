import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        AppEnvironment.shared.reminderScheduler.registerCategory()
        AppEnvironment.shared.reminderScheduler.requestAuthorization()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let payload = RollbackReminderPayload(userInfo: response.notification.request.content.userInfo)
        DispatchQueue.main.async {
            defer { completionHandler() }
            guard let payload else { return }
            let environment = AppEnvironment.shared

            switch response.actionIdentifier {
            case RollbackReminderPayload.proceedActionIdentifier:
                do {
                    try environment.recordGoNoGoDecision.execute(changeID: payload.changeID, decision: .proceed, rationale: nil)
                } catch {
                    environment.reminderScheduler.reportDecisionFailure(error, reference: payload.reference)
                }
            case RollbackReminderPayload.rollBackActionIdentifier:
                let reason = (response as? UNTextInputNotificationResponse)?.userText
                do {
                    try environment.recordGoNoGoDecision.execute(changeID: payload.changeID, decision: .rollBack, rationale: reason)
                } catch {
                    environment.reminderScheduler.reportDecisionFailure(error, reference: payload.reference)
                }
            case UNNotificationDefaultActionIdentifier:
                AppRouter.shared.openChange(payload.changeID, showingGoNoGo: true)
            default:
                break
            }
        }
    }
}
