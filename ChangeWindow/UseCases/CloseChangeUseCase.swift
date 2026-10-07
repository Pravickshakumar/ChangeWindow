import Foundation

enum CloseChangeError: LocalizedError, Equatable {
    case changeNotFound
    case changeNotInProgress(reference: String)
    case mandatoryStepsOutstanding(count: Int)
    case noImplementationEvidence

    var errorDescription: String? {
        switch self {
        case .changeNotFound:
            return "This change is no longer in your schedule"
        case .changeNotInProgress(let reference):
            return "\(reference) isn't in progress"
        case .mandatoryStepsOutstanding(let count):
            return count == 1 ? "1 mandatory step is still open" : "\(count) mandatory steps are still open"
        case .noImplementationEvidence:
            return "There's no evidence the change worked"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .changeNotFound:
            return "Go back to your schedule and refresh."
        case .changeNotInProgress:
            return "Only a change that's being implemented can be closed as completed."
        case .mandatoryStepsOutstanding:
            return "Finish the remaining steps, or record a No-Go and roll back if they can't be done in the window."
        case .noImplementationEvidence:
            return "Add at least one post-check — a screenshot of healthy cluster status, a log excerpt or a note — so the PIR can confirm success."
        }
    }
}

struct CloseChangeUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(changeID: UUID) throws -> ChangeRequest {
        guard var change = try repository.change(withID: changeID) else { throw CloseChangeError.changeNotFound }
        guard change.status == .inProgress else { throw CloseChangeError.changeNotInProgress(reference: change.reference) }

        let outstanding = change.outstandingMandatorySteps.count
        guard outstanding == 0 else { throw CloseChangeError.mandatoryStepsOutstanding(count: outstanding) }
        guard !change.evidence.isEmpty else { throw CloseChangeError.noImplementationEvidence }

        let now = clock.now
        if change.goNoGo == nil {
            change.goNoGo = GoNoGoRecord(decision: .proceed, recordedAt: now,
                                         rationale: "Runbook completed before the rollback deadline")
        }
        change.status = .completed
        change.closedAt = now
        try repository.save(change)
        return change
    }
}
