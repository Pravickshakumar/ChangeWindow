import Foundation
import WidgetKit

struct WidgetSnapshotPublisher {
    let repository: ChangeRequestRepository
    let clock: DomainClock
    let store = WidgetSnapshotStore()

    func publish() {
        let changes = (try? repository.allChanges()) ?? []
        let snapshot = Self.makeSnapshot(from: changes, now: clock.now)
        try? store.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func makeSnapshot(from changes: [ChangeRequest], now: Date) -> WidgetSnapshot {
        let active = changes.first { $0.status == .inProgress }.map { change in
            WidgetSnapshot.ActiveChange(
                changeID: change.id,
                reference: change.reference,
                summary: change.summary,
                clientName: change.clientName,
                completedSteps: change.completedStepCount,
                totalSteps: change.runbook.count,
                currentStepNumber: change.currentStep?.sequence,
                currentStepInstruction: change.currentStep?.instruction,
                rollbackDeadline: change.window.rollbackDeadline,
                windowClosesAt: change.window.closesAt,
                goNoGoRecorded: change.goNoGo != nil)
        }

        let next = changes
            .filter { $0.status == .scheduled && !$0.window.hasClosed(at: now) }
            .min { $0.window.opensAt < $1.window.opensAt }
            .map {
                WidgetSnapshot.UpcomingChange(changeID: $0.id, reference: $0.reference, summary: $0.summary,
                                              clientName: $0.clientName, windowOpensAt: $0.window.opensAt)
            }

        let order: [ChangeStatus: Int] = [.inProgress: 0, .scheduled: 1, .completed: 2, .rolledBack: 2]
        let targets = changes
            .filter { $0.isAcceptingEvidence(at: now) }
            .sorted { (order[$0.status] ?? 9, $0.window.opensAt) < (order[$1.status] ?? 9, $1.window.opensAt) }
            .prefix(8)
            .map {
                WidgetSnapshot.EvidenceTarget(changeID: $0.id, reference: $0.reference,
                                              summary: $0.summary, statusLabel: $0.status.displayName)
            }

        return WidgetSnapshot(generatedAt: now, activeChange: active, nextChange: next, evidenceTargets: Array(targets))
    }
}
