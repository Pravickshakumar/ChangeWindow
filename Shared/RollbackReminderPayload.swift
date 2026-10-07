import Foundation

struct RollbackReminderPayload: Equatable {
    static let categoryIdentifier = "ROLLBACK_DECISION"
    static let proceedActionIdentifier = "PROCEED_WITH_CHANGE"
    static let rollBackActionIdentifier = "ROLL_BACK_CHANGE"

    var changeID: UUID
    var reference: String
    var summary: String
    var clientName: String
    var completedSteps: Int
    var totalSteps: Int
    var currentStepInstruction: String?
    var rollbackDeadline: Date
    var windowClosesAt: Date

    var rollbackAllowanceMinutes: Int {
        Int(windowClosesAt.timeIntervalSince(rollbackDeadline) / 60)
    }

    var userInfo: [String: Any] {
        var info: [String: Any] = [
            "changeID": changeID.uuidString,
            "reference": reference,
            "summary": summary,
            "clientName": clientName,
            "completedSteps": completedSteps,
            "totalSteps": totalSteps,
            "rollbackDeadline": rollbackDeadline.timeIntervalSince1970,
            "windowClosesAt": windowClosesAt.timeIntervalSince1970,
        ]
        if let currentStepInstruction { info["currentStepInstruction"] = currentStepInstruction }
        return info
    }

    init(changeID: UUID, reference: String, summary: String, clientName: String,
         completedSteps: Int, totalSteps: Int, currentStepInstruction: String?,
         rollbackDeadline: Date, windowClosesAt: Date) {
        self.changeID = changeID
        self.reference = reference
        self.summary = summary
        self.clientName = clientName
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.currentStepInstruction = currentStepInstruction
        self.rollbackDeadline = rollbackDeadline
        self.windowClosesAt = windowClosesAt
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo["changeID"] as? String,
              let id = UUID(uuidString: idString),
              let reference = userInfo["reference"] as? String,
              let deadline = userInfo["rollbackDeadline"] as? Double,
              let closes = userInfo["windowClosesAt"] as? Double
        else { return nil }
        self.init(
            changeID: id,
            reference: reference,
            summary: (userInfo["summary"] as? String) ?? "",
            clientName: (userInfo["clientName"] as? String) ?? "",
            completedSteps: (userInfo["completedSteps"] as? Int) ?? 0,
            totalSteps: (userInfo["totalSteps"] as? Int) ?? 0,
            currentStepInstruction: userInfo["currentStepInstruction"] as? String,
            rollbackDeadline: Date(timeIntervalSince1970: deadline),
            windowClosesAt: Date(timeIntervalSince1970: closes))
    }
}
