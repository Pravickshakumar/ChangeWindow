import Foundation

enum BeginChangeError: LocalizedError, Equatable {
    case changeNotFound
    case changeNotScheduled(ChangeStatus)
    case windowNotYetOpen(opensAt: Date)
    case windowHasClosed(closedAt: Date)
    case anotherChangeInProgress(reference: String)

    var errorDescription: String? {
        switch self {
        case .changeNotFound:
            return "This change is no longer in your schedule"
        case .changeNotScheduled(let status):
            return "This change is already \(status.displayName.lowercased())"
        case .windowNotYetOpen(let opensAt):
            return "The window doesn't open until \(DomainFormat.time(opensAt))"
        case .windowHasClosed(let closedAt):
            return "The window closed at \(DomainFormat.time(closedAt))"
        case .anotherChangeInProgress(let reference):
            return "\(reference) is still in progress"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .changeNotFound:
            return "Go back to your schedule and refresh."
        case .changeNotScheduled:
            return "Only scheduled changes can be started. Open the change to continue or review it."
        case .windowNotYetOpen:
            return "Starting early is unapproved work. Do your pre-checks now and begin when the window opens."
        case .windowHasClosed:
            return "Don't start this change. Contact the change manager to reschedule it for a new window."
        case .anotherChangeInProgress:
            return "Close or roll back that change first — running two changes at once makes it impossible to tell which one caused an incident."
        }
    }
}

struct BeginChangeWindowUseCase {
    let repository: ChangeRequestRepository
    let clock: DomainClock

    @discardableResult
    func execute(changeID: UUID) throws -> ChangeRequest {
        guard var change = try repository.change(withID: changeID) else { throw BeginChangeError.changeNotFound }
        guard change.status == .scheduled else { throw BeginChangeError.changeNotScheduled(change.status) }

        let now = clock.now
        guard change.window.hasOpened(at: now) else {
            throw BeginChangeError.windowNotYetOpen(opensAt: change.window.opensAt)
        }
        guard !change.window.hasClosed(at: now) else {
            throw BeginChangeError.windowHasClosed(closedAt: change.window.closesAt)
        }
        if let running = try repository.changesInProgress().first(where: { $0.id != change.id }) {
            throw BeginChangeError.anotherChangeInProgress(reference: running.reference)
        }

        change.status = .inProgress
        change.startedAt = now
        try repository.save(change)
        return change
    }
}
