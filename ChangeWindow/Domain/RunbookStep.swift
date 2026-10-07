import Foundation

struct RunbookStep: Identifiable, Equatable {
    let id: UUID
    var sequence: Int
    var instruction: String
    var isMandatory: Bool
    var completedAt: Date?
    var engineerNote: String?

    var isComplete: Bool { completedAt != nil }

    init(id: UUID = UUID(), sequence: Int, instruction: String, isMandatory: Bool = true,
         completedAt: Date? = nil, engineerNote: String? = nil) {
        self.id = id
        self.sequence = sequence
        self.instruction = instruction
        self.isMandatory = isMandatory
        self.completedAt = completedAt
        self.engineerNote = engineerNote
    }
}
