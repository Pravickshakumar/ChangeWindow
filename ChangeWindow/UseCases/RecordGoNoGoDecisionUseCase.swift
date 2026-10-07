import Foundation

enum GoNoGoDecisionError: LocalizedError, Equatable {
    case changeNotFound
    case changeNotInProgress(reference: String)
    case decisionAlreadyRecorded(GoNoGoDecision)
    case rollbackRationaleRequired

    var errorDescription: String? {
        switch self {
        case .changeNotFound:
            return "This change is no longer in your schedule"
        case .changeNotInProgress(let reference):
            return "\(reference) isn't being implemented right now"
        case .decisionAlreadyRecorded(let decision):
            return "A decision was already recorded: \(decision.displayName)"
        case .rollbackRationaleRequired:
            return "Say why you're rolling back"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .changeNotFound:
            return "Go back to your schedule and refresh."
        case .changeNotInProgress:
            return "Go/No-Go can only be recorded while a change is in progress."
        case .decisionAlreadyRecorded:
            return "A Go/No-Go call can't be changed after it's made. Add a note to the evidence log to explain what happened next."
        case .rollbackRationaleRequired:
            return "One line is enough — for example \"Node 2 failed to rejoin the cluster\". The change manager needs it for the incident review."
        }
    }
}

struct RecordGoNoGoDecisionUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(changeID: UUID, decision: GoNoGoDecision, rationale: String?) throws -> ChangeRequest {
        guard var change = try repository.change(withID: changeID) else { throw GoNoGoDecisionError.changeNotFound }
        guard change.status == .inProgress else {
            throw GoNoGoDecisionError.changeNotInProgress(reference: change.reference)
        }
        if let existing = change.goNoGo { throw GoNoGoDecisionError.decisionAlreadyRecorded(existing.decision) }

        let trimmed = rationale?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if decision == .rollBack && trimmed.isEmpty { throw GoNoGoDecisionError.rollbackRationaleRequired }

        let now = clock.now
        change.goNoGo = GoNoGoRecord(decision: decision, recordedAt: now, rationale: trimmed.isEmpty ? nil : trimmed)
        if decision == .rollBack {
            change.status = .rolledBack
            change.closedAt = now
        }
        try repository.save(change)
        return change
    }
}
