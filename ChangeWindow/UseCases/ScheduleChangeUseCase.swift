import Foundation

struct RunbookStepDraft: Identifiable, Equatable {
    let id: UUID
    var instruction: String
    var isMandatory: Bool

    init(id: UUID = UUID(), instruction: String = "", isMandatory: Bool = true) {
        self.id = id
        self.instruction = instruction
        self.isMandatory = isMandatory
    }
}

struct ChangeRequestDraft: Equatable {
    var reference: String
    var summary: String
    var clientName: String
    var opensAt: Date
    var closesAt: Date
    var rollbackDeadline: Date
    var runbook: [RunbookStepDraft]
}

enum ScheduleChangeError: LocalizedError, Equatable {
    case changeReferenceMissing
    case duplicateChangeReference(String)
    case windowClosesBeforeItOpens
    case windowAlreadyClosed
    case rollbackDeadlineOutsideWindow
    case runbookHasNoSteps

    var errorDescription: String? {
        switch self {
        case .changeReferenceMissing:
            return "This change has no CAB reference"
        case .duplicateChangeReference(let reference):
            return "\(reference) is already in your schedule"
        case .windowClosesBeforeItOpens:
            return "The window closes before it opens"
        case .windowAlreadyClosed:
            return "This maintenance window has already ended"
        case .rollbackDeadlineOutsideWindow:
            return "The rollback deadline must fall inside the window"
        case .runbookHasNoSteps:
            return "The runbook is empty"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .changeReferenceMissing:
            return "Copy the change number from the approved ticket (for example CHG0041932) so evidence lines up with the CAB record."
        case .duplicateChangeReference:
            return "Open the existing change from your schedule instead of adding it twice."
        case .windowClosesBeforeItOpens:
            return "Check the approved start and end times on the CAB approval and correct them."
        case .windowAlreadyClosed:
            return "A change can't be run outside its approved window. Ask the change manager to re-approve it for a new window."
        case .rollbackDeadlineOutsideWindow:
            return "Set the deadline after the window opens and early enough to finish the back-out plan before the window closes."
        case .runbookHasNoSteps:
            return "Add at least one step from the approved implementation plan."
        }
    }
}

struct ScheduleChangeUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(_ draft: ChangeRequestDraft) throws -> ChangeRequest {
        let reference = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !reference.isEmpty else { throw ScheduleChangeError.changeReferenceMissing }
        guard draft.closesAt > draft.opensAt else { throw ScheduleChangeError.windowClosesBeforeItOpens }
        guard draft.closesAt > clock.now else { throw ScheduleChangeError.windowAlreadyClosed }
        guard draft.rollbackDeadline > draft.opensAt, draft.rollbackDeadline < draft.closesAt else {
            throw ScheduleChangeError.rollbackDeadlineOutsideWindow
        }

        let instructions = draft.runbook
            .map { ($0.instruction.trimmingCharacters(in: .whitespacesAndNewlines), $0.isMandatory) }
            .filter { !$0.0.isEmpty }
        guard !instructions.isEmpty else { throw ScheduleChangeError.runbookHasNoSteps }

        if try repository.change(withReference: reference) != nil {
            throw ScheduleChangeError.duplicateChangeReference(reference)
        }

        let steps = instructions.enumerated().map { index, step in
            RunbookStep(sequence: index + 1, instruction: step.0, isMandatory: step.1)
        }
        let change = ChangeRequest(
            reference: reference,
            summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            clientName: draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines),
            window: MaintenanceWindow(opensAt: draft.opensAt, closesAt: draft.closesAt,
                                      rollbackDeadline: draft.rollbackDeadline),
            runbook: steps)
        try repository.save(change)
        return change
    }
}
