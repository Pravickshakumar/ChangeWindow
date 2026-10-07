import Foundation

struct SharedEvidenceImporter {
    let inbox = SharedEvidenceInbox()
    let attachEvidence: AttachEvidenceUseCase

    struct Outcome {
        var imported = 0
        var rejected: [Error] = []
    }

    func importPendingEvidence() -> Outcome {
        var outcome = Outcome()
        for item in inbox.pendingItems() {
            do {
                try attachEvidence.execute(
                    changeID: item.changeID,
                    kind: EvidenceKind(shared: item.kind),
                    content: item.content,
                    caption: item.caption,
                    source: .shareSheet,
                    capturedAt: item.capturedAt)
                outcome.imported += 1
                inbox.remove(item)
            } catch let error as AttachEvidenceError {
                outcome.rejected.append(error)
                inbox.remove(item)
            } catch {
                outcome.rejected.append(error)
            }
        }
        return outcome
    }
}

extension EvidenceKind {
    init(shared: SharedEvidenceKind) {
        switch shared {
        case .vendorLink: self = .vendorLink
        case .logExcerpt: self = .logExcerpt
        case .consoleScreenshot: self = .consoleScreenshot
        }
    }
}
