import XCTest
@testable import ChangeWindow

final class ImplementationUseCaseTests: XCTestCase {
    private var clock: FixedClock!

    override func setUp() { clock = FixedClock(tenPM) }

    func test_beginningChange_beforeWindowOpens_isRejectedWithOpeningTime() {
        let change = Fixture.change()
        let repository = MockChangeRequestRepository([change])
        clock.now = tenPM.addingTimeInterval(.minutes(-1))

        XCTAssertThrowsError(try BeginChangeWindowUseCase(repository: repository, clock: clock).execute(changeID: change.id)) { error in
            XCTAssertEqual(error as? BeginChangeError, .windowNotYetOpen(opensAt: tenPM))
        }
    }

    func test_beginningChange_exactlyWhenWindowOpens_isAllowed() throws {
        let change = Fixture.change()
        let repository = MockChangeRequestRepository([change])

        let started = try BeginChangeWindowUseCase(repository: repository, clock: clock).execute(changeID: change.id)

        XCTAssertEqual(started.status, .inProgress)
        XCTAssertEqual(started.startedAt, tenPM)
    }

    func test_beginningChange_whileAnotherChangeIsInProgress_isRejected() {
        let running = Fixture.change(reference: "CHG0000001", status: .inProgress)
        let next = Fixture.change(reference: "CHG0000002")
        let repository = MockChangeRequestRepository([running, next])

        XCTAssertThrowsError(try BeginChangeWindowUseCase(repository: repository, clock: clock).execute(changeID: next.id)) { error in
            XCTAssertEqual(error as? BeginChangeError, .anotherChangeInProgress(reference: "CHG0000001"))
        }
    }

    func test_completingStep_whileEarlierMandatoryStepIsOutstanding_isRejected() {
        let change = Fixture.change(status: .inProgress, completedSteps: 0)
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try CompleteRunbookStepUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, stepID: change.runbook[1].id)) { error in
            XCTAssertEqual(error as? CompleteRunbookStepError, .earlierMandatoryStepOutstanding(sequence: 1))
        }
    }

    func test_completingStep_afterSkippingOptionalStep_isAllowed() throws {
        let change = Fixture.change(status: .inProgress, completedSteps: 2)
        let repository = MockChangeRequestRepository([change])
        clock.now = tenPM.addingTimeInterval(.hours(1))

        let updated = try CompleteRunbookStepUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, stepID: change.runbook[3].id, engineerNote: "  Node back online  ")

        XCTAssertTrue(updated.runbook[3].isComplete)
        XCTAssertEqual(updated.runbook[3].engineerNote, "Node back online")
        XCTAssertTrue(updated.outstandingMandatorySteps.isEmpty)
    }

    func test_completingStep_afterRollbackDeadlineWithoutGoNoGo_requiresDecisionFirst() {
        let change = Fixture.change(status: .inProgress, completedSteps: 1)
        let repository = MockChangeRequestRepository([change])
        clock.now = change.window.rollbackDeadline

        XCTAssertThrowsError(try CompleteRunbookStepUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, stepID: change.runbook[1].id)) { error in
            XCTAssertEqual(error as? CompleteRunbookStepError, .goNoGoDecisionOverdue(deadline: change.window.rollbackDeadline))
        }
    }

    func test_completingStep_afterDeadlineOnceGoIsRecorded_isAllowed() throws {
        let go = GoNoGoRecord(decision: .proceed, recordedAt: tenPM.addingTimeInterval(.hours(2.4)), rationale: nil)
        let change = Fixture.change(status: .inProgress, completedSteps: 1, goNoGo: go)
        let repository = MockChangeRequestRepository([change])
        clock.now = tenPM.addingTimeInterval(.hours(3))

        let updated = try CompleteRunbookStepUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, stepID: change.runbook[1].id)

        XCTAssertTrue(updated.runbook[1].isComplete)
    }

    func test_rollingBack_withoutRationale_isRejected() {
        let change = Fixture.change(status: .inProgress, completedSteps: 1)
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try RecordGoNoGoDecisionUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, decision: .rollBack, rationale: "   ")) { error in
            XCTAssertEqual(error as? GoNoGoDecisionError, .rollbackRationaleRequired)
        }
        XCTAssertEqual(repository.saveCount, 0)
    }

    func test_rollingBack_withRationale_closesChangeAsRolledBack() throws {
        let change = Fixture.change(status: .inProgress, completedSteps: 1)
        let repository = MockChangeRequestRepository([change])
        clock.now = tenPM.addingTimeInterval(.hours(2))

        let updated = try RecordGoNoGoDecisionUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, decision: .rollBack, rationale: "Node 2 failed to rejoin cluster")

        XCTAssertEqual(updated.status, .rolledBack)
        XCTAssertEqual(updated.closedAt, clock.now)
        XCTAssertEqual(updated.goNoGo?.rationale, "Node 2 failed to rejoin cluster")
    }

    func test_recordingGoNoGo_whenDecisionAlreadyMade_cannotBeOverwritten() {
        let go = GoNoGoRecord(decision: .proceed, recordedAt: tenPM, rationale: nil)
        let change = Fixture.change(status: .inProgress, goNoGo: go)
        let repository = MockChangeRequestRepository([change])

        XCTAssertThrowsError(try RecordGoNoGoDecisionUseCase(repository: repository, clock: clock)
            .execute(changeID: change.id, decision: .rollBack, rationale: "Changed my mind")) { error in
            XCTAssertEqual(error as? GoNoGoDecisionError, .decisionAlreadyRecorded(.proceed))
        }
    }
}
