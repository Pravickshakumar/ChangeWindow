import Foundation

struct ChangeRequest: Identifiable, Equatable {
    static let postImplementationReviewPeriod: TimeInterval = 24 * 60 * 60

    let id: UUID
    var reference: String
    var summary: String
    var clientName: String
    var window: MaintenanceWindow
    var status: ChangeStatus
    var runbook: [RunbookStep]
    var evidence: [EvidenceItem]
    var goNoGo: GoNoGoRecord?
    var startedAt: Date?
    var closedAt: Date?

    init(id: UUID = UUID(), reference: String, summary: String, clientName: String,
         window: MaintenanceWindow, status: ChangeStatus = .scheduled,
         runbook: [RunbookStep], evidence: [EvidenceItem] = [], goNoGo: GoNoGoRecord? = nil,
         startedAt: Date? = nil, closedAt: Date? = nil) {
        self.id = id
        self.reference = reference
        self.summary = summary
        self.clientName = clientName
        self.window = window
        self.status = status
        self.runbook = runbook.sorted { $0.sequence < $1.sequence }
        self.evidence = evidence.sorted { $0.capturedAt < $1.capturedAt }
        self.goNoGo = goNoGo
        self.startedAt = startedAt
        self.closedAt = closedAt
    }

    var currentStep: RunbookStep? { runbook.first { !$0.isComplete } }

    var completedStepCount: Int { runbook.filter(\.isComplete).count }

    var outstandingMandatorySteps: [RunbookStep] {
        runbook.filter { $0.isMandatory && !$0.isComplete }
    }

    func isGoNoGoDecisionOverdue(at date: Date) -> Bool {
        status == .inProgress && goNoGo == nil && date >= window.rollbackDeadline
    }

    func isAcceptingEvidence(at date: Date) -> Bool {
        switch status {
        case .scheduled, .inProgress:
            return true
        case .completed, .rolledBack:
            guard let closedAt else { return true }
            return date.timeIntervalSince(closedAt) <= Self.postImplementationReviewPeriod
        case .cancelled:
            return false
        }
    }
}
