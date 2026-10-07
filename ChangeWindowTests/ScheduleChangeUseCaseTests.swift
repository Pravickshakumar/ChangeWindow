import XCTest
@testable import ChangeWindow

final class ScheduleChangeUseCaseTests: XCTestCase {
    private var repository: MockChangeRequestRepository!
    private var useCase: ScheduleChangeUseCase!

    override func setUp() {
        repository = MockChangeRequestRepository()
        useCase = ScheduleChangeUseCase(repository: repository, clock: FixedClock(tenPM))
    }

    func test_schedulingApprovedChange_addsItToScheduleWithNumberedRunbook() throws {
        let change = try useCase.execute(Fixture.draft(reference: "  chg0050001 "))

        XCTAssertEqual(change.reference, "CHG0050001", "CAB references are normalised to upper case")
        XCTAssertEqual(change.status, .scheduled)
        XCTAssertEqual(change.runbook.map(\.sequence), [1, 2])
        XCTAssertNotNil(try repository.change(withID: change.id))
    }

    func test_schedulingChange_whenRollbackDeadlineIsAfterWindowCloses_isRejected() {
        let draft = Fixture.draft(rollbackAfterOpening: .hours(5), windowLength: .hours(4))

        XCTAssertThrowsError(try useCase.execute(draft)) { error in
            XCTAssertEqual(error as? ScheduleChangeError, .rollbackDeadlineOutsideWindow)
        }
        XCTAssertEqual(repository.saveCount, 0)
    }

    func test_schedulingChange_whenRollbackDeadlineEqualsWindowClose_isRejected() {
        let draft = Fixture.draft(rollbackAfterOpening: .hours(4), windowLength: .hours(4))

        XCTAssertThrowsError(try useCase.execute(draft)) { error in
            XCTAssertEqual(error as? ScheduleChangeError, .rollbackDeadlineOutsideWindow)
        }
    }

    func test_schedulingChange_withReferenceAlreadyInSchedule_isRejectedCaseInsensitively() throws {
        try useCase.execute(Fixture.draft(reference: "CHG0050001"))

        XCTAssertThrowsError(try useCase.execute(Fixture.draft(reference: "chg0050001"))) { error in
            XCTAssertEqual(error as? ScheduleChangeError, .duplicateChangeReference("CHG0050001"))
        }
    }

    func test_schedulingChange_withOnlyBlankRunbookSteps_isRejected() {
        XCTAssertThrowsError(try useCase.execute(Fixture.draft(steps: ["   ", ""]))) { error in
            XCTAssertEqual(error as? ScheduleChangeError, .runbookHasNoSteps)
        }
    }

    func test_schedulingChange_forWindowThatHasAlreadyEnded_isRejected() {
        let draft = Fixture.draft(opensIn: .hours(-5), windowLength: .hours(4))

        XCTAssertThrowsError(try useCase.execute(draft)) { error in
            XCTAssertEqual(error as? ScheduleChangeError, .windowAlreadyClosed)
        }
    }
}
