import Foundation

protocol ChangeRequestRepository {
    func allChanges() throws -> [ChangeRequest]
    func change(withID id: UUID) throws -> ChangeRequest?
    func change(withReference reference: String) throws -> ChangeRequest?
    func changesInProgress() throws -> [ChangeRequest]
    func scheduledChanges(openingBetween start: Date, and end: Date) throws -> [ChangeRequest]
    func changesAwaitingGoNoGo(at date: Date) throws -> [ChangeRequest]
    func save(_ change: ChangeRequest) throws
}

enum ChangeRecordStoreError: LocalizedError, Equatable {
    case storeUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .storeUnavailable: return "Your change records couldn't be opened"
        case .saveFailed: return "That update wasn't saved to this iPhone"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storeUnavailable:
            return "Restart ChangeWindow. Until it opens, follow the runbook in the change ticket and note step times on paper."
        case .saveFailed:
            return "Nothing on the change was altered. Try again; if it fails again, write the step time down and record it after the window."
        }
    }
}
