import Foundation

enum DemoChangeSeeder {
    static func seed(into repository: ChangeRequestRepository, now: Date = Date()) throws {
        guard try repository.allChanges().isEmpty else { return }

        let liveSteps = [
            "Confirm backup job for HV-CLUS01 VMs completed successfully",
            "Raise maintenance mode in monitoring for HV-NODE01–04",
            "Drain roles from HV-NODE01 and pause the node",
            "Install cumulative update on HV-NODE01 and reboot",
            "Resume HV-NODE01 and confirm it rejoins the cluster",
            "Repeat drain/patch/resume for HV-NODE02",
            "Run cluster validation (Test-Cluster) and save the report",
            "Remove maintenance mode and confirm no alerts",
        ].enumerated().map { index, text in
            RunbookStep(sequence: index + 1, instruction: text, isMandatory: index != 6,
                        completedAt: index < 3 ? now.addingTimeInterval(TimeInterval(-35 + index * 10) * 60) : nil)
        }

        let live = ChangeRequest(
            reference: "CHG0041932",
            summary: "Patch Hyper-V cluster HV-CLUS01",
            clientName: "Metro Health Network",
            window: MaintenanceWindow(opensAt: now.addingTimeInterval(-40 * 60),
                                      closesAt: now.addingTimeInterval(2 * 3600 + 20 * 60),
                                      rollbackDeadline: now.addingTimeInterval(20 * 60)),
            status: .inProgress,
            runbook: liveSteps,
            evidence: [EvidenceItem(kind: .engineerNote,
                                    content: "Pre-check: all 4 nodes Up, CSV healthy, last backup 21:04 successful.",
                                    capturedAt: now.addingTimeInterval(-38 * 60), source: .engineer, stepSequence: 1)],
            startedAt: now.addingTimeInterval(-38 * 60))

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let opens = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow)!
        let upcoming = ChangeRequest(
            reference: "CHG0042007",
            summary: "Migrate wave 3 VMs from vSphere to Hyper-V",
            clientName: "Regional Energy Co",
            window: MaintenanceWindow(opensAt: opens, closesAt: opens.addingTimeInterval(6 * 3600),
                                      rollbackDeadline: opens.addingTimeInterval(4 * 3600)),
            runbook: [
                RunbookStep(sequence: 1, instruction: "Confirm application owners have stopped services"),
                RunbookStep(sequence: 2, instruction: "Take final snapshot of wave 3 VMs in vCenter"),
                RunbookStep(sequence: 3, instruction: "Run SCVMM V2V conversion for each VM"),
                RunbookStep(sequence: 4, instruction: "Power on in Hyper-V and validate network/IP"),
                RunbookStep(sequence: 5, instruction: "Application owners confirm smoke tests"),
            ])

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let closedAt = yesterday.addingTimeInterval(-2 * 3600)
        let completed = ChangeRequest(
            reference: "CHG0041870",
            summary: "Replace failed PSU in SAN controller B",
            clientName: "Metro Health Network",
            window: MaintenanceWindow(opensAt: closedAt.addingTimeInterval(-3 * 3600), closesAt: closedAt.addingTimeInterval(3600),
                                      rollbackDeadline: closedAt.addingTimeInterval(-3600)),
            status: .completed,
            runbook: [RunbookStep(sequence: 1, instruction: "Hot-swap PSU and confirm green status",
                                  completedAt: closedAt.addingTimeInterval(-600))],
            evidence: [EvidenceItem(kind: .engineerNote, content: "Controller B both PSUs healthy in array manager.",
                                    capturedAt: closedAt.addingTimeInterval(-300), source: .engineer, stepSequence: 1)],
            goNoGo: GoNoGoRecord(decision: .proceed, recordedAt: closedAt.addingTimeInterval(-900), rationale: nil),
            startedAt: closedAt.addingTimeInterval(-2 * 3600),
            closedAt: closedAt)

        try repository.save(completed)
        try repository.save(upcoming)
        try repository.save(live)
    }
}
