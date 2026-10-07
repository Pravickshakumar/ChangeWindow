import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<RollbackDecisionCard>?

    func didReceive(_ notification: UNNotification) {
        guard let payload = RollbackReminderPayload(userInfo: notification.request.content.userInfo) else { return }
        let card = RollbackDecisionCard(payload: payload)

        if let host {
            host.rootView = card
        } else {
            let host = UIHostingController(rootView: card)
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.view.backgroundColor = .clear
            view.addSubview(host.view)
            host.didMove(toParent: self)
            self.host = host
        }
        preferredContentSize = CGSize(width: view.bounds.width, height: 230)
    }
}

struct RollbackDecisionCard: View {
    let payload: RollbackReminderPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(payload.reference).font(.headline.monospaced())
                Spacer()
                Text(payload.clientName).font(.caption).foregroundStyle(.secondary)
            }
            Text(payload.summary).font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                Gauge(value: Double(payload.completedSteps), in: 0...Double(max(payload.totalSteps, 1))) {
                    Text("Steps")
                } currentValueLabel: {
                    Text("\(payload.completedSteps)/\(payload.totalSteps)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if context.date >= payload.rollbackDeadline {
                            Text("Rollback deadline passed").font(.title3.weight(.bold)).foregroundStyle(.red)
                        } else {
                            Text("Decide in \(DomainCountdown.text(from: context.date, to: payload.rollbackDeadline))")
                                .font(.title3.monospacedDigit().weight(.bold))
                        }
                    }
                    Text("Back-out time after deadline: \(payload.rollbackAllowanceMinutes) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let next = payload.currentStepInstruction {
                Label(next, systemImage: "arrow.right.circle").font(.callout).lineLimit(2)
            } else {
                Label("All runbook steps complete", systemImage: "checkmark.circle").font(.callout)
            }
        }
        .padding()
    }
}

enum DomainCountdown {
    static func text(from now: Date, to target: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
