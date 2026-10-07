import Foundation

enum AttachEvidenceError: LocalizedError, Equatable {
    case evidenceIsEmpty
    case changeNotFound
    case changeNotAcceptingEvidence(reference: String)

    var errorDescription: String? {
        switch self {
        case .evidenceIsEmpty:
            return "There's nothing to attach"
        case .changeNotFound:
            return "The change this evidence was for is no longer in your schedule"
        case .changeNotAcceptingEvidence(let reference):
            return "\(reference) is closed to new evidence"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .evidenceIsEmpty:
            return "Type a note, or share a link, log text or screenshot into ChangeWindow."
        case .changeNotFound:
            return "Attach it to the current change instead, or save it in the change ticket directly."
        case .changeNotAcceptingEvidence:
            return "Evidence can be added up to 24 hours after a change closes. Add anything later straight to the change ticket."
        }
    }
}

struct AttachEvidenceUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(changeID: UUID, kind: EvidenceKind, content: String, caption: String?,
                 source: EvidenceSource, capturedAt: Date? = nil) throws -> ChangeRequest {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AttachEvidenceError.evidenceIsEmpty }
        guard var change = try repository.change(withID: changeID) else { throw AttachEvidenceError.changeNotFound }

        let now = clock.now
        guard change.isAcceptingEvidence(at: now) else {
            throw AttachEvidenceError.changeNotAcceptingEvidence(reference: change.reference)
        }

        let cleanCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = EvidenceItem(
            kind: kind,
            content: trimmed,
            caption: (cleanCaption?.isEmpty ?? true) ? nil : cleanCaption,
            capturedAt: capturedAt ?? now,
            source: source,
            stepSequence: change.currentStep?.sequence ?? change.runbook.last(where: \.isComplete)?.sequence)
        change.evidence.append(item)
        change.evidence.sort { $0.capturedAt < $1.capturedAt }
        try repository.save(change)
        return change
    }
}
