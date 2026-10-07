import Foundation

@MainActor
final class EvidenceLogViewModel: ObservableObject {
    @Published private(set) var change: ChangeRequest?
    @Published var alert: DomainAlert?

    private let changeID: UUID
    private let environment: AppEnvironment

    init(changeID: UUID, environment: AppEnvironment) {
        self.changeID = changeID
        self.environment = environment
    }

    var evidence: [EvidenceItem] {
        guard let change else { return [] }
        return change.evidence.reversed()
    }

    var isAcceptingEvidence: Bool { change?.isAcceptingEvidence(at: environment.clock.now) ?? false }

    func load() {
        do {
            change = try environment.repository.change(withID: changeID)
        } catch {
            alert = DomainAlert(error: error)
        }
    }

    func addNote(_ text: String) -> DomainAlert? {
        do {
            change = try environment.attachEvidence.execute(changeID: changeID, kind: .engineerNote,
                                                            content: text, caption: nil, source: .engineer)
            return nil
        } catch {
            return DomainAlert(error: error)
        }
    }
}
