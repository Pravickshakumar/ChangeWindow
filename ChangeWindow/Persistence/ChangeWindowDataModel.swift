import CoreData

enum ChangeWindowDataModel {
    static let shared: NSManagedObjectModel = makeModel()

    private static func makeModel() -> NSManagedObjectModel {
        let change = NSEntityDescription()
        change.name = "ChangeRequestRecord"
        change.managedObjectClassName = NSStringFromClass(ChangeRequestRecord.self)

        let step = NSEntityDescription()
        step.name = "RunbookStepRecord"
        step.managedObjectClassName = NSStringFromClass(RunbookStepRecord.self)

        let evidence = NSEntityDescription()
        evidence.name = "EvidenceItemRecord"
        evidence.managedObjectClassName = NSStringFromClass(EvidenceItemRecord.self)

        change.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("reference", .stringAttributeType),
            attribute("summary", .stringAttributeType),
            attribute("clientName", .stringAttributeType),
            attribute("windowOpensAt", .dateAttributeType),
            attribute("windowClosesAt", .dateAttributeType),
            attribute("rollbackDeadline", .dateAttributeType),
            attribute("statusRaw", .stringAttributeType),
            attribute("goNoGoDecisionRaw", .stringAttributeType, optional: true),
            attribute("goNoGoRecordedAt", .dateAttributeType, optional: true),
            attribute("goNoGoRationale", .stringAttributeType, optional: true),
            attribute("startedAt", .dateAttributeType, optional: true),
            attribute("closedAt", .dateAttributeType, optional: true),
        ]
        step.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("sequence", .integer16AttributeType),
            attribute("instruction", .stringAttributeType),
            attribute("isMandatory", .booleanAttributeType),
            attribute("completedAt", .dateAttributeType, optional: true),
            attribute("engineerNote", .stringAttributeType, optional: true),
        ]
        evidence.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("kindRaw", .stringAttributeType),
            attribute("content", .stringAttributeType),
            attribute("caption", .stringAttributeType, optional: true),
            attribute("capturedAt", .dateAttributeType),
            attribute("sourceRaw", .stringAttributeType),
            attribute("stepSequence", .integer16AttributeType),
        ]

        relate(parent: change, children: step, toMany: "runbookSteps", inverse: "changeRequest")
        relate(parent: change, children: evidence, toMany: "evidenceItems", inverse: "changeRequest")

        change.uniquenessConstraints = [["reference"]]

        let model = NSManagedObjectModel()
        model.entities = [change, step, evidence]
        return model
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static func relate(parent: NSEntityDescription, children: NSEntityDescription,
                               toMany: String, inverse: String) {
        let parentToChildren = NSRelationshipDescription()
        parentToChildren.name = toMany
        parentToChildren.destinationEntity = children
        parentToChildren.minCount = 0
        parentToChildren.maxCount = 0
        parentToChildren.deleteRule = .cascadeDeleteRule
        parentToChildren.isOptional = true

        let childToParent = NSRelationshipDescription()
        childToParent.name = inverse
        childToParent.destinationEntity = parent
        childToParent.minCount = 0
        childToParent.maxCount = 1
        childToParent.deleteRule = .nullifyDeleteRule
        childToParent.isOptional = true

        parentToChildren.inverseRelationship = childToParent
        childToParent.inverseRelationship = parentToChildren

        parent.properties.append(parentToChildren)
        children.properties.append(childToParent)
    }
}
