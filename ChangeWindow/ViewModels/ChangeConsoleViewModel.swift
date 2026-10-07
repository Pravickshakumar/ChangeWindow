import Foundation

@MainActor
final class ChangeConsoleViewModel: ObservableObject {
    @Published private(set) var change: ChangeRequest?
    @Published var alert: DomainAlert?

    let changeID: UUID
    private let environment: AppEnvironment

    init(changeID: UUID, environment: AppEnvironment) {
        self.changeID = changeID
        self.environment = environment
    }

    var now: Date { environment.clock.now }

    func load() {
        do {
            change = try environment.repository.change(withID: changeID)
        } catch {
            alert = DomainAlert(error: error)
        }
    }

    func beginChange() {
        do {
            change = try environment.beginChangeWindow.execute(changeID: changeID)
        } catch {
            alert = DomainAlert(error: error)
        }
    }

    func complete(_ step: RunbookStep, note: String) -> DomainAlert? {
        perform { try environment.completeRunbookStep.execute(changeID: changeID, stepID: step.id, engineerNote: note) }
    }

    func recordGoNoGo(_ decision: GoNoGoDecision, rationale: String) -> DomainAlert? {
        perform { try environment.recordGoNoGoDecision.execute(changeID: changeID, decision: decision, rationale: rationale) }
    }

    func closeChange() -> DomainAlert? {
        perform { try environment.closeChange.execute(changeID: changeID) }
    }

    func previewReminder() {
        guard let change else { return }
        environment.reminderScheduler.previewReminder(for: change)
    }

    private func perform(_ action: () throws -> ChangeRequest) -> DomainAlert? {
        do {
            change = try action()
            return nil
        } catch {
            return DomainAlert(error: error)
        }
    }
}
