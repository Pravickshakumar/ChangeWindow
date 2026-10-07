import Foundation

enum CompleteRunbookStepError: LocalizedError, Equatable {
    case changeNotFound
    case stepNotFound
    case changeNotInProgress(reference: String)
    case stepAlreadyCompleted(sequence: Int)
    case earlierMandatoryStepOutstanding(sequence: Int)
    case goNoGoDecisionOverdue(deadline: Date)

    var errorDescription: String? {
        switch self {
        case .changeNotFound:
            return "This change is no longer in your schedule"
        case .stepNotFound:
            return "That step isn't in this runbook any more"
        case .changeNotInProgress(let reference):
            return "\(reference) hasn't been started"
        case .stepAlreadyCompleted(let sequence):
            return "Step \(sequence) is already marked complete"
        case .earlierMandatoryStepOutstanding(let sequence):
            return "Step \(sequence) hasn't been completed"
        case .goNoGoDecisionOverdue(let deadline):
            return "The rollback deadline passed at \(DomainFormat.time(deadline))"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .changeNotFound, .stepNotFound:
            return "Go back to the change and refresh the runbook."
        case .changeNotInProgress:
            return "Tap Begin Change once the window is open, then work through the runbook."
        case .stepAlreadyCompleted:
            return "No action needed. Add a note in the evidence log if something about it changed."
        case .earlierMandatoryStepOutstanding:
            return "Mandatory steps must be done in order. Complete that step first, or stop and raise it with the change manager if it can't be done."
        case .goNoGoDecisionOverdue:
            return "Stop and record a Go/No-Go decision before doing anything else. If in doubt, roll back while there's still time in the window."
        }
    }
}

struct CompleteRunbookStepUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(changeID: UUID, stepID: UUID, engineerNote: String? = nil) throws -> ChangeRequest {
        guard var change = try repository.change(withID: changeID) else { throw CompleteRunbookStepError.changeNotFound }
        guard change.status == .inProgress else {
            throw CompleteRunbookStepError.changeNotInProgress(reference: change.reference)
        }
        guard let index = change.runbook.firstIndex(where: { $0.id == stepID }) else {
            throw CompleteRunbookStepError.stepNotFound
        }
        let step = change.runbook[index]
        guard !step.isComplete else { throw CompleteRunbookStepError.stepAlreadyCompleted(sequence: step.sequence) }

        let now = clock.now
        if change.isGoNoGoDecisionOverdue(at: now) {
            throw CompleteRunbookStepError.goNoGoDecisionOverdue(deadline: change.window.rollbackDeadline)
        }
        if let blocking = change.runbook[..<index].first(where: { $0.isMandatory && !$0.isComplete }) {
            throw CompleteRunbookStepError.earlierMandatoryStepOutstanding(sequence: blocking.sequence)
        }

        change.runbook[index].completedAt = now
        let note = engineerNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        change.runbook[index].engineerNote = (note?.isEmpty ?? true) ? nil : note
        try repository.save(change)
        return change
    }
}
