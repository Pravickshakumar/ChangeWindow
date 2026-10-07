import Foundation

enum ChangeStatus: String, CaseIterable, Equatable {
    case scheduled
    case inProgress
    case completed
    case rolledBack
    case cancelled

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .rolledBack: return "Rolled back"
        case .cancelled: return "Cancelled"
        }
    }

    var isClosed: Bool { self == .completed || self == .rolledBack || self == .cancelled }
}

enum GoNoGoDecision: String, Equatable {
    case proceed
    case rollBack

    var displayName: String {
        switch self {
        case .proceed: return "Go — proceed with change"
        case .rollBack: return "No-Go — roll back"
        }
    }
}

struct GoNoGoRecord: Equatable {
    var decision: GoNoGoDecision
    var recordedAt: Date
    var rationale: String?
}
