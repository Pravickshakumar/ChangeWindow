import XCTest
@testable import ChangeWindow

final class CloseOutUseCaseTests: XCTestCase {
    private let clock = FixedClock(tenPM.addingTimeInterval(.hours(2)))

    func test_closingChange_withMandatoryStepsOutstanding_reportsHowManyRemain() {
        let change = Fixture.change(status: .inProgress, completedSteps: 1, evidence: [Fixture.postCheckNote()])
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try CloseChangeUseCase(repository: repository, clock: clock).execute(changeID: change.id)) { error in
            XCTAssertEqual(error as? CloseChangeError, .mandatoryStepsOutstanding(count: 2))
        }
    }

    func test_closingChange_withoutAnyEvidence_isRejected() {
        let change = Fixture.change(status: .inProgress, completedSteps: 4)
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try CloseChangeUseCase(repository: repository, clock: clock).execute(changeID: change.id)) { error in
            XCTAssertEqual(error as? CloseChangeError, .noImplementationEvidence)
        }
    }

    func test_closingChange_withRunbookDoneAndEvidence_completesAndRecordsImplicitGo() throws {
        let change = Fixture.change(status: .inProgress, completedSteps: 4, evidence: [Fixture.postCheckNote()])
        let repository = MockChangeRequestRepository([change])

        let closed = try CloseChangeUseCase(repository: repository, clock: clock).execute(changeID: change.id)

        XCTAssertEqual(closed.status, .completed)
        XCTAssertEqual(closed.closedAt, clock.now)
        XCTAssertEqual(closed.goNoGo?.decision, .proceed)
    }

    func test_closingChange_whenStorageFails_leavesChangeInProgress() throws {
        let change = Fixture.change(status: .inProgress, completedSteps: 4, evidence: [Fixture.postCheckNote()])
        let repository = MockChangeRequestRepository([change])
        repository.failNextSave = true

        XCTAssertThrowsError(try CloseChangeUseCase(repository: repository, clock: clock).execute(changeID: change.id)) { error in
            XCTAssertEqual(error as? ChangeRecordStoreError, .saveFailed)
        }
        XCTAssertEqual(try repository.change(withID: change.id)?.status, .inProgress)
    }

    func test_attachingEvidence_duringChange_isTaggedWithCurrentStep() throws {
        let change = Fixture.change(status: .inProgress, completedSteps: 1)
        let repository = MockChangeRequestRepository([change])

        let updated = try AttachEvidenceUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, kind: .vendorLink, content: "https://learn.microsoft.com/kb/5031364",
                     caption: "KB for cluster warning", source: .shareSheet)

        XCTAssertEqual(updated.evidence.last?.stepSequence, 2)
        XCTAssertEqual(updated.evidence.last?.source, .shareSheet)
    }

    func test_attachingEvidence_justInsideReviewPeriod_isAccepted() throws {
        let closedAt = tenPM.addingTimeInterval(.hours(3))
        let change = Fixture.change(status: .completed, completedSteps: 4, closedAt: closedAt)
        let repository = MockChangeRequestRepository([change])
        let clock = FixedClock(closedAt.addingTimeInterval(ChangeRequest.postImplementationReviewPeriod))

        XCTAssertNoThrow(try AttachEvidenceUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, kind: .engineerNote, content: "Monitoring clean overnight", caption: nil, source: .engineer))
    }

    func test_attachingEvidence_moreThanADayAfterClosure_isRejected() {
        let closedAt = tenPM.addingTimeInterval(.hours(3))
        let change = Fixture.change(status: .completed, completedSteps: 4, closedAt: closedAt)
        let repository = MockChangeRequestRepository([change])
        let clock = FixedClock(closedAt.addingTimeInterval(ChangeRequest.postImplementationReviewPeriod + 1))

        XCTAssertThrowsError(try AttachEvidenceUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, kind: .engineerNote, content: "Late note", caption: nil, source: .engineer)) { error in
            XCTAssertEqual(error as? AttachEvidenceError, .changeNotAcceptingEvidence(reference: "CHG0041932"))
        }
    }

    func test_attachingBlankEvidence_isRejected() {
        let change = Fixture.change(status: .inProgress)
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try AttachEvidenceUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, kind: .engineerNote, content: "  \n ", caption: nil, source: .engineer)) { error in
            XCTAssertEqual(error as? AttachEvidenceError, .evidenceIsEmpty)
        }
    }

    func test_everyDomainError_tellsTheEngineerWhatToDoNext() {
        let errors: [LocalizedError] = [
            ScheduleChangeError.changeReferenceMissing,
            ScheduleChangeError.duplicateChangeReference("CHG1"),
            ScheduleChangeError.windowClosesBeforeItOpens,
            ScheduleChangeError.windowAlreadyClosed,
            ScheduleChangeError.rollbackDeadlineOutsideWindow,
            ScheduleChangeError.runbookHasNoSteps,
            BeginChangeError.changeNotFound,
            BeginChangeError.changeNotScheduled(.completed),
            BeginChangeError.windowNotYetOpen(opensAt: tenPM),
            BeginChangeError.windowHasClosed(closedAt: tenPM),
            BeginChangeError.anotherChangeInProgress(reference: "CHG1"),
            CompleteRunbookStepError.changeNotFound,
            CompleteRunbookStepError.stepNotFound,
            CompleteRunbookStepError.changeNotInProgress(reference: "CHG1"),
            CompleteRunbookStepError.stepAlreadyCompleted(sequence: 1),
            CompleteRunbookStepError.earlierMandatoryStepOutstanding(sequence: 1),
            CompleteRunbookStepError.goNoGoDecisionOverdue(deadline: tenPM),
            GoNoGoDecisionError.changeNotFound,
            GoNoGoDecisionError.changeNotInProgress(reference: "CHG1"),
            GoNoGoDecisionError.decisionAlreadyRecorded(.proceed),
            GoNoGoDecisionError.rollbackRationaleRequired,
            CloseChangeError.changeNotFound,
            CloseChangeError.changeNotInProgress(reference: "CHG1"),
            CloseChangeError.mandatoryStepsOutstanding(count: 2),
            CloseChangeError.noImplementationEvidence,
            AttachEvidenceError.evidenceIsEmpty,
            AttachEvidenceError.changeNotFound,
            AttachEvidenceError.changeNotAcceptingEvidence(reference: "CHG1"),
            ChangeRecordStoreError.storeUnavailable,
            ChangeRecordStoreError.saveFailed,
        ]
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "\(error) needs a description")
            XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true, "\(error) needs a next step")
        }
    }
}
