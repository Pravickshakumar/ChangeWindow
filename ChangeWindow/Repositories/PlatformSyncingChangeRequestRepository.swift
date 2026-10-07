import Foundation

final class PlatformSyncingChangeRequestRepository: ChangeRequestRepository {
    private let base: ChangeRequestRepository
    private let afterSave: () -> Void

    init(wrapping base: ChangeRequestRepository, afterSave: @escaping () -> Void) {
        self.base = base
        self.afterSave = afterSave
    }

    func allChanges() throws -> [ChangeRequest] { try base.allChanges() }
    func change(withID id: UUID) throws -> ChangeRequest? { try base.change(withID: id) }
    func change(withReference reference: String) throws -> ChangeRequest? { try base.change(withReference: reference) }
    func changesInProgress() throws -> [ChangeRequest] { try base.changesInProgress() }
    func scheduledChanges(openingBetween start: Date, and end: Date) throws -> [ChangeRequest] {
        try base.scheduledChanges(openingBetween: start, and: end)
    }
    func changesAwaitingGoNoGo(at date: Date) throws -> [ChangeRequest] { try base.changesAwaitingGoNoGo(at: date) }

    func save(_ change: ChangeRequest) throws {
        try base.save(change)
        afterSave()
    }
}
