import CoreData

@objc(ChangeRequestRecord)
final class ChangeRequestRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var reference: String
    @NSManaged var summary: String
    @NSManaged var clientName: String
    @NSManaged var windowOpensAt: Date
    @NSManaged var windowClosesAt: Date
    @NSManaged var rollbackDeadline: Date
    @NSManaged var statusRaw: String
    @NSManaged var goNoGoDecisionRaw: String?
    @NSManaged var goNoGoRecordedAt: Date?
    @NSManaged var goNoGoRationale: String?
    @NSManaged var startedAt: Date?
    @NSManaged var closedAt: Date?
    @NSManaged var runbookSteps: Set<RunbookStepRecord>
    @NSManaged var evidenceItems: Set<EvidenceItemRecord>
}

@objc(RunbookStepRecord)
final class RunbookStepRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sequence: Int16
    @NSManaged var instruction: String
    @NSManaged var isMandatory: Bool
    @NSManaged var completedAt: Date?
    @NSManaged var engineerNote: String?
    @NSManaged var changeRequest: ChangeRequestRecord?
}

@objc(EvidenceItemRecord)
final class EvidenceItemRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var kindRaw: String
    @NSManaged var content: String
    @NSManaged var caption: String?
    @NSManaged var capturedAt: Date
    @NSManaged var sourceRaw: String
    @NSManaged var stepSequence: Int16
    @NSManaged var changeRequest: ChangeRequestRecord?
}
