import Foundation

extension Notification.Name {
    static let changeRecordsDidChange = Notification.Name("ChangeWindow.changeRecordsDidChange")
}

final class AppEnvironment {
    static let shared = AppEnvironment()

    let clock: DomainClock
    let repository: ChangeRequestRepository
    let reminderScheduler: RollbackReminderScheduler
    private let snapshotPublisher: WidgetSnapshotPublisher

    init(persistence: PersistenceController = PersistenceController(), clock: DomainClock = SystemClock()) {
        self.clock = clock
        let coreData = CoreDataChangeRequestRepository(persistence: persistence)
        let publisher = WidgetSnapshotPublisher(repository: coreData, clock: clock)
        let scheduler = RollbackReminderScheduler()
        self.reminderScheduler = scheduler
        self.snapshotPublisher = publisher
        self.repository = PlatformSyncingChangeRequestRepository(wrapping: coreData) {
            publisher.publish()
            scheduler.reschedule(for: (try? coreData.allChanges()) ?? [], now: clock.now)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .changeRecordsDidChange, object: nil)
            }
        }
    }

    var scheduleChange: ScheduleChangeUseCase { .init(repository: repository, clock: clock) }
    var beginChangeWindow: BeginChangeWindowUseCase { .init(repository: repository, clock: clock) }
    var completeRunbookStep: CompleteRunbookStepUseCase { .init(repository: repository, clock: clock) }
    var recordGoNoGoDecision: RecordGoNoGoDecisionUseCase { .init(repository: repository, clock: clock) }
    var closeChange: CloseChangeUseCase { .init(repository: repository, clock: clock) }
    var attachEvidence: AttachEvidenceUseCase { .init(repository: repository, clock: clock) }

    @discardableResult
    func synchroniseSystemSurfaces() -> SharedEvidenceImporter.Outcome {
        let outcome = SharedEvidenceImporter(attachEvidence: attachEvidence).importPendingEvidence()
        snapshotPublisher.publish()
        return outcome
    }
}
