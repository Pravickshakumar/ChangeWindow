import Foundation
import UserNotifications

struct RollbackReminderScheduler {
    static let leadTime: TimeInterval = 15 * 60
    private static let identifierPrefix = "rollback-decision-"

    private let center = UNUserNotificationCenter.current()

    func registerCategory() {
        let proceed = UNNotificationAction(
            identifier: RollbackReminderPayload.proceedActionIdentifier,
            title: "Go — proceed",
            options: [.authenticationRequired])
        let rollBack = UNTextInputNotificationAction(
            identifier: RollbackReminderPayload.rollBackActionIdentifier,
            title: "No-Go — roll back…",
            options: [.authenticationRequired, .destructive],
            textInputButtonTitle: "Roll back",
            textInputPlaceholder: "Reason for rolling back")
        let category = UNNotificationCategory(
            identifier: RollbackReminderPayload.categoryIdentifier,
            actions: [proceed, rollBack],
            intentIdentifiers: [],
            options: [.customDismissAction])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func reschedule(for changes: [ChangeRequest], now: Date) {
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            for change in changes where change.goNoGo == nil
                && (change.status == .scheduled || change.status == .inProgress) {
                let fireDate = change.window.rollbackDeadline.addingTimeInterval(-Self.leadTime)
                guard fireDate > now else { continue }
                schedule(Self.payload(for: change), after: fireDate.timeIntervalSince(now))
            }
        }
    }

    func previewReminder(for change: ChangeRequest) {
        schedule(Self.payload(for: change), after: 5)
    }

    static func payload(for change: ChangeRequest) -> RollbackReminderPayload {
        RollbackReminderPayload(
            changeID: change.id,
            reference: change.reference,
            summary: change.summary,
            clientName: change.clientName,
            completedSteps: change.completedStepCount,
            totalSteps: change.runbook.count,
            currentStepInstruction: change.currentStep?.instruction,
            rollbackDeadline: change.window.rollbackDeadline,
            windowClosesAt: change.window.closesAt)
    }

    private func schedule(_ payload: RollbackReminderPayload, after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Go/No-Go due for \(payload.reference)"
        content.subtitle = payload.summary
        content.body = "Rollback deadline \(DomainFormat.time(payload.rollbackDeadline)). "
            + "\(payload.completedSteps) of \(payload.totalSteps) steps complete."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = RollbackReminderPayload.categoryIdentifier
        content.threadIdentifier = payload.changeID.uuidString
        content.userInfo = payload.userInfo

        let request = UNNotificationRequest(
            identifier: Self.identifierPrefix + payload.changeID.uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false))
        center.add(request)
    }

    func reportDecisionFailure(_ error: Error, reference: String?) {
        let content = UNMutableNotificationContent()
        let localized = error as? LocalizedError
        content.title = localized?.errorDescription ?? "Your Go/No-Go wasn't recorded"
        content.body = localized?.recoverySuggestion ?? "Open ChangeWindow and record the decision on the change."
        if let reference { content.subtitle = reference }
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
