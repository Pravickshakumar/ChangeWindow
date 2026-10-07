import CoreData

final class CoreDataChangeRequestRepository: ChangeRequestRepository {
    private let context: NSManagedObjectContext
    private let storeLoadError: Error?

    init(persistence: PersistenceController) {
        self.context = persistence.container.viewContext
        self.storeLoadError = persistence.loadError
    }

    func allChanges() throws -> [ChangeRequest] {
        try fetch(predicate: nil)
    }

    func change(withID id: UUID) throws -> ChangeRequest? {
        try fetch(predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }

    func change(withReference reference: String) throws -> ChangeRequest? {
        try fetch(predicate: NSPredicate(format: "reference ==[c] %@", reference), limit: 1).first
    }

    func changesInProgress() throws -> [ChangeRequest] {
        try fetch(predicate: NSPredicate(format: "statusRaw == %@", ChangeStatus.inProgress.rawValue))
    }

    func scheduledChanges(openingBetween start: Date, and end: Date) throws -> [ChangeRequest] {
        try fetch(predicate: NSPredicate(
            format: "statusRaw == %@ AND windowOpensAt >= %@ AND windowOpensAt < %@",
            ChangeStatus.scheduled.rawValue, start as NSDate, end as NSDate))
    }

    func changesAwaitingGoNoGo(at date: Date) throws -> [ChangeRequest] {
        try fetch(predicate: NSPredicate(
            format: "statusRaw == %@ AND goNoGoDecisionRaw == nil AND rollbackDeadline <= %@",
            ChangeStatus.inProgress.rawValue, date as NSDate))
    }

    func save(_ change: ChangeRequest) throws {
        if storeLoadError != nil { throw ChangeRecordStoreError.storeUnavailable }
        try context.performAndWait {
            let request = NSFetchRequest<ChangeRequestRecord>(entityName: "ChangeRequestRecord")
            request.predicate = NSPredicate(format: "id == %@", change.id as CVarArg)
            request.fetchLimit = 1
            let record = try context.fetch(request).first ?? ChangeRequestRecord(context: context)

            record.id = change.id
            record.reference = change.reference
            record.summary = change.summary
            record.clientName = change.clientName
            record.windowOpensAt = change.window.opensAt
            record.windowClosesAt = change.window.closesAt
            record.rollbackDeadline = change.window.rollbackDeadline
            record.statusRaw = change.status.rawValue
            record.goNoGoDecisionRaw = change.goNoGo?.decision.rawValue
            record.goNoGoRecordedAt = change.goNoGo?.recordedAt
            record.goNoGoRationale = change.goNoGo?.rationale
            record.startedAt = change.startedAt
            record.closedAt = change.closedAt

            syncRunbook(change.runbook, into: record)
            syncEvidence(change.evidence, into: record)

            do {
                if context.hasChanges { try context.save() }
            } catch {
                context.rollback()
                throw ChangeRecordStoreError.saveFailed
            }
        }
    }

    private func fetch(predicate: NSPredicate?, limit: Int = 0) throws -> [ChangeRequest] {
        if storeLoadError != nil { throw ChangeRecordStoreError.storeUnavailable }
        return try context.performAndWait {
            let request = NSFetchRequest<ChangeRequestRecord>(entityName: "ChangeRequestRecord")
            request.predicate = predicate
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(key: "windowOpensAt", ascending: true)]
            request.relationshipKeyPathsForPrefetching = ["runbookSteps", "evidenceItems"]
            return try context.fetch(request).map(ChangeRequest.init(record:))
        }
    }

    private func syncRunbook(_ steps: [RunbookStep], into record: ChangeRequestRecord) {
        var existing = Dictionary(uniqueKeysWithValues: record.runbookSteps.map { ($0.id, $0) })
        for step in steps {
            let stepRecord = existing.removeValue(forKey: step.id) ?? RunbookStepRecord(context: context)
            stepRecord.id = step.id
            stepRecord.sequence = Int16(step.sequence)
            stepRecord.instruction = step.instruction
            stepRecord.isMandatory = step.isMandatory
            stepRecord.completedAt = step.completedAt
            stepRecord.engineerNote = step.engineerNote
            stepRecord.changeRequest = record
        }
        for orphan in existing.values { context.delete(orphan) }
    }

    private func syncEvidence(_ items: [EvidenceItem], into record: ChangeRequestRecord) {
        var existing = Dictionary(uniqueKeysWithValues: record.evidenceItems.map { ($0.id, $0) })
        for item in items {
            let itemRecord = existing.removeValue(forKey: item.id) ?? EvidenceItemRecord(context: context)
            itemRecord.id = item.id
            itemRecord.kindRaw = item.kind.rawValue
            itemRecord.content = item.content
            itemRecord.caption = item.caption
            itemRecord.capturedAt = item.capturedAt
            itemRecord.sourceRaw = item.source.rawValue
            itemRecord.stepSequence = Int16(item.stepSequence ?? 0)
            itemRecord.changeRequest = record
        }
        for orphan in existing.values { context.delete(orphan) }
    }
}

private extension ChangeRequest {
    init(record: ChangeRequestRecord) {
        let goNoGo: GoNoGoRecord? = {
            guard let raw = record.goNoGoDecisionRaw,
                  let decision = GoNoGoDecision(rawValue: raw),
                  let recordedAt = record.goNoGoRecordedAt else { return nil }
            return GoNoGoRecord(decision: decision, recordedAt: recordedAt, rationale: record.goNoGoRationale)
        }()

        self.init(
            id: record.id,
            reference: record.reference,
            summary: record.summary,
            clientName: record.clientName,
            window: MaintenanceWindow(opensAt: record.windowOpensAt, closesAt: record.windowClosesAt,
                                      rollbackDeadline: record.rollbackDeadline),
            status: ChangeStatus(rawValue: record.statusRaw) ?? .scheduled,
            runbook: record.runbookSteps.map {
                RunbookStep(id: $0.id, sequence: Int($0.sequence), instruction: $0.instruction,
                            isMandatory: $0.isMandatory, completedAt: $0.completedAt, engineerNote: $0.engineerNote)
            },
            evidence: record.evidenceItems.map {
                EvidenceItem(id: $0.id, kind: EvidenceKind(rawValue: $0.kindRaw) ?? .engineerNote,
                             content: $0.content, caption: $0.caption, capturedAt: $0.capturedAt,
                             source: EvidenceSource(rawValue: $0.sourceRaw) ?? .engineer,
                             stepSequence: $0.stepSequence == 0 ? nil : Int($0.stepSequence))
            },
            goNoGo: goNoGo,
            startedAt: record.startedAt,
            closedAt: record.closedAt)
    }
}
