import Foundation
import SwiftUI

@MainActor
final class ScheduleChangeViewModel: ObservableObject {
    @Published var draft: ChangeRequestDraft
    @Published var alert: DomainAlert?

    private let scheduleChange: ScheduleChangeUseCase

    init(environment: AppEnvironment) {
        self.scheduleChange = environment.scheduleChange
        let calendar = Calendar.current
        let now = environment.clock.now
        var opens = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        if opens < now { opens = calendar.date(byAdding: .day, value: 1, to: opens) ?? opens }
        draft = ChangeRequestDraft(
            reference: "", summary: "", clientName: "",
            opensAt: opens,
            closesAt: opens.addingTimeInterval(4 * 3600),
            rollbackDeadline: opens.addingTimeInterval(2.5 * 3600),
            runbook: [RunbookStepDraft(), RunbookStepDraft()])
    }

    func addStep() { draft.runbook.append(RunbookStepDraft()) }

    func removeSteps(at offsets: IndexSet) { draft.runbook.remove(atOffsets: offsets) }

    func moveSteps(from source: IndexSet, to destination: Int) {
        draft.runbook.move(fromOffsets: source, toOffset: destination)
    }

    func schedule() -> Bool {
        do {
            try scheduleChange.execute(draft)
            return true
        } catch {
            alert = DomainAlert(error: error)
            return false
        }
    }
}
