import Foundation

struct WidgetSnapshot: Codable, Equatable {
    struct ActiveChange: Codable, Equatable {
        var changeID: UUID
        var reference: String
        var summary: String
        var clientName: String
        var completedSteps: Int
        var totalSteps: Int
        var currentStepNumber: Int?
        var currentStepInstruction: String?
        var rollbackDeadline: Date
        var windowClosesAt: Date
        var goNoGoRecorded: Bool
    }

    struct UpcomingChange: Codable, Equatable {
        var changeID: UUID
        var reference: String
        var summary: String
        var clientName: String
        var windowOpensAt: Date
    }

    struct EvidenceTarget: Codable, Equatable, Identifiable {
        var changeID: UUID
        var reference: String
        var summary: String
        var statusLabel: String
        var id: UUID { changeID }
    }

    var generatedAt: Date
    var activeChange: ActiveChange?
    var nextChange: UpcomingChange?
    var evidenceTargets: [EvidenceTarget]

    static let empty = WidgetSnapshot(generatedAt: .distantPast, activeChange: nil, nextChange: nil, evidenceTargets: [])

    static var preview: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            generatedAt: now,
            activeChange: ActiveChange(
                changeID: UUID(), reference: "CHG0041932",
                summary: "Patch Hyper-V cluster HV-CLUS01", clientName: "Metro Health Network",
                completedSteps: 3, totalSteps: 8, currentStepNumber: 4,
                currentStepInstruction: "Drain roles from HV-NODE02 and pause the node",
                rollbackDeadline: now.addingTimeInterval(25 * 60),
                windowClosesAt: now.addingTimeInterval(3 * 3600), goNoGoRecorded: false),
            nextChange: nil,
            evidenceTargets: [])
    }
}

struct WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"

    private var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(Self.fileName)
    }

    func write(_ snapshot: WidgetSnapshot) throws {
        guard let fileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    func read() -> WidgetSnapshot? {
        guard let fileURL else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        return (try? JSONDecoder().decode(WidgetSnapshot.self, from: data)) ?? .empty
    }
}
