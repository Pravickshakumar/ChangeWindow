import Foundation

enum EvidenceKind: String, Equatable, CaseIterable {
    case vendorLink
    case logExcerpt
    case consoleScreenshot
    case engineerNote

    var displayName: String {
        switch self {
        case .vendorLink: return "Vendor reference"
        case .logExcerpt: return "Log excerpt"
        case .consoleScreenshot: return "Console screenshot"
        case .engineerNote: return "Engineer note"
        }
    }

    var symbolName: String {
        switch self {
        case .vendorLink: return "link"
        case .logExcerpt: return "text.alignleft"
        case .consoleScreenshot: return "photo"
        case .engineerNote: return "square.and.pencil"
        }
    }
}

enum EvidenceSource: String, Equatable {
    case engineer
    case shareSheet
}

struct EvidenceItem: Identifiable, Equatable {
    let id: UUID
    var kind: EvidenceKind
    var content: String
    var caption: String?
    var capturedAt: Date
    var source: EvidenceSource
    var stepSequence: Int?

    init(id: UUID = UUID(), kind: EvidenceKind, content: String, caption: String? = nil,
         capturedAt: Date, source: EvidenceSource, stepSequence: Int? = nil) {
        self.id = id
        self.kind = kind
        self.content = content
        self.caption = caption
        self.capturedAt = capturedAt
        self.source = source
        self.stepSequence = stepSequence
    }
}
