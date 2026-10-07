import Foundation

@MainActor
final class ChangeScheduleViewModel: ObservableObject {
    @Published private(set) var inProgress: [ChangeRequest] = []
    @Published private(set) var upcoming: [ChangeRequest] = []
    @Published private(set) var recentlyClosed: [ChangeRequest] = []
    @Published var alert: DomainAlert?

    private let repository: ChangeRequestRepository
    private let clock: DomainClock

    init(environment: AppEnvironment) {
        self.repository = environment.repository
        self.clock = environment.clock
    }

    var hasNoChanges: Bool { inProgress.isEmpty && upcoming.isEmpty && recentlyClosed.isEmpty }
    var now: Date { clock.now }

    func load() {
        do {
            let changes = try repository.allChanges()
            inProgress = changes.filter { $0.status == .inProgress }
            upcoming = changes.filter { $0.status == .scheduled }
            recentlyClosed = changes
                .filter(\.status.isClosed)
                .sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        } catch {
            alert = DomainAlert(error: error)
        }
    }

    func loadSampleChanges() {
        do {
            try DemoChangeSeeder.seed(into: repository, now: clock.now)
            load()
        } catch {
            alert = DomainAlert(error: error)
        }
    }
}
