import Foundation
@testable import ChangeWindow

final class MockChangeRequestRepository: ChangeRequestRepository {
    private(set) var changesByID: [UUID: ChangeRequest] = [:]
    private(set) var saveCount = 0
    var failNextSave = false

    init(_ changes: [ChangeRequest] = []) {
        changes.forEach { changesByID[$0.id] = $0 }
    }

    func allChanges() throws -> [ChangeRequest] {
        changesByID.values.sorted { $0.window.opensAt < $1.window.opensAt }
    }

    func change(withID id: UUID) throws -> ChangeRequest? { changesByID[id] }

    func change(withReference reference: String) throws -> ChangeRequest? {
        changesByID.values.first { $0.reference.caseInsensitiveCompare(reference) == .orderedSame }
    }

    func changesInProgress() throws -> [ChangeRequest] {
        changesByID.values.filter { $0.status == .inProgress }
    }

    func scheduledChanges(openingBetween start: Date, and end: Date) throws -> [ChangeRequest] {
        changesByID.values.filter { $0.status == .scheduled && $0.window.opensAt >= start && $0.window.opensAt < end }
    }

    func changesAwaitingGoNoGo(at date: Date) throws -> [ChangeRequest] {
        changesByID.values.filter { $0.isGoNoGoDecisionOverdue(at: date) }
    }

    func save(_ change: ChangeRequest) throws {
        if failNextSave {
            failNextSave = false
            throw ChangeRecordStoreError.saveFailed
        }
        changesByID[change.id] = change
        saveCount += 1
    }
}

final class FixedClock: DomainClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

let tenPM = Date(timeIntervalSince1970: 1_790_000_000)

extension TimeInterval {
    static func minutes(_ value: Double) -> TimeInterval { value * 60 }
    static func hours(_ value: Double) -> TimeInterval { value * 3600 }
}

enum Fixture {
    static func change(reference: String = "CHG0041932",
                       status: ChangeStatus = .scheduled,
                       completedSteps: Int = 0,
                       evidence: [EvidenceItem] = [],
                       goNoGo: GoNoGoRecord? = nil,
                       closedAt: Date? = nil) -> ChangeRequest {
        let steps = (1...4).map { number in
            RunbookStep(sequence: number,
                        instruction: "Step \(number) instruction",
                        isMandatory: number != 3,
                        completedAt: number <= completedSteps ? tenPM.addingTimeInterval(.minutes(Double(number * 5))) : nil)
        }
        return ChangeRequest(
            reference: reference,
            summary: "Patch Hyper-V cluster HV-CLUS01",
            clientName: "Metro Health Network",
            window: MaintenanceWindow(opensAt: tenPM,
                                      closesAt: tenPM.addingTimeInterval(.hours(4)),
                                      rollbackDeadline: tenPM.addingTimeInterval(.hours(2.5))),
            status: status,
            runbook: steps,
            evidence: evidence,
            goNoGo: goNoGo,
            startedAt: status == .scheduled ? nil : tenPM,
            closedAt: closedAt)
    }

    static func postCheckNote(at date: Date = tenPM.addingTimeInterval(.hours(1))) -> EvidenceItem {
        EvidenceItem(kind: .engineerNote, content: "All nodes Up after patching", capturedAt: date, source: .engineer)
    }

    static func draft(reference: String = "CHG0050001",
                      opensIn: TimeInterval = .hours(1),
                      rollbackAfterOpening: TimeInterval = .hours(2),
                      windowLength: TimeInterval = .hours(4),
                      steps: [String] = ["Drain node", "Patch node"]) -> ChangeRequestDraft {
        let opens = tenPM.addingTimeInterval(opensIn)
        return ChangeRequestDraft(
            reference: reference, summary: "Firmware update", clientName: "Regional Energy Co",
            opensAt: opens, closesAt: opens.addingTimeInterval(windowLength),
            rollbackDeadline: opens.addingTimeInterval(rollbackAfterOpening),
            runbook: steps.map { RunbookStepDraft(instruction: $0) })
    }
}
