import XCTest
@testable import UlulaWake

final class SleepSafetyCoordinatorTests: XCTestCase {
    func testAlreadyNormalDoesNotInvokeSudo() {
        let mock = MockSleepController(observedState: false)
        let result = SleepSafetyCoordinator(controller: mock).restoreNormalSleep()

        XCTAssertTrue(result.isConfirmedNormal)
        XCTAssertFalse(result.commandAttempted)
        XCTAssertEqual(mock.requestedStates, [])
    }

    func testLaunchResidualIsRestoredAndReadBack() {
        let mock = MockSleepController(
            observedState: true,
            results: [result(requested: false, actual: false)]
        )
        let outcome = SleepSafetyCoordinator(controller: mock).restoreNormalSleep()

        XCTAssertTrue(outcome.isConfirmedNormal)
        XCTAssertEqual(mock.requestedStates, [false])
    }

    func testUnknownStateStillAttemptsSafeRestore() {
        let mock = MockSleepController(
            observedState: nil,
            results: [result(requested: false, actual: false)]
        )
        let outcome = SleepSafetyCoordinator(controller: mock).restoreNormalSleep()

        XCTAssertTrue(outcome.isConfirmedNormal)
        XCTAssertEqual(mock.requestedStates, [false])
    }

    func testFailedRestoreCannotBeReportedAsNormal() {
        let mock = MockSleepController(
            observedState: true,
            results: [result(requested: false, actual: true, exitCode: 1)]
        )
        let outcome = SleepSafetyCoordinator(controller: mock).restoreNormalSleep()

        XCTAssertFalse(outcome.isConfirmedNormal)
        XCTAssertEqual(outcome.actualState, true)
    }

    func testNonzeroExitIsStillSafeWhenReadBackIsOff() {
        let outcome = result(requested: false, actual: false, exitCode: 1)
        XCTAssertTrue(outcome.isConfirmedNormal)
        XCTAssertFalse(outcome.succeeded)
    }

    func testEnableRequiresSuccessfulCommandAndReadBack() {
        let mock = MockSleepController(
            observedState: false,
            results: [result(requested: true, actual: true)]
        )
        let outcome = SleepSafetyCoordinator(controller: mock).enableKeeping()

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(mock.requestedStates, [true])
    }

    func testSleepDisabledParserDistinguishesFailureFromOff() {
        XCTAssertEqual(SystemProbe.parseSleepDisabled(" SleepDisabled 1\n"), true)
        XCTAssertEqual(SystemProbe.parseSleepDisabled(" SleepDisabled 0\n"), false)
        XCTAssertNil(SystemProbe.parseSleepDisabled("System-wide power settings:\n"))
    }

    func testShellQuoteEscapesSingleQuotes() {
        XCTAssertEqual(AuthorizationService.shellQuote("a'b"), "'a'\\''b'")
    }

    private static func result(
        requested: Bool,
        actual: Bool?,
        exitCode: Int32 = 0
    ) -> SleepCommandResult {
        SleepCommandResult(
            requestedState: requested,
            actualState: actual,
            commandExitCode: exitCode,
            diagnostic: "test",
            commandAttempted: true
        )
    }

    private func result(
        requested: Bool,
        actual: Bool?,
        exitCode: Int32 = 0
    ) -> SleepCommandResult {
        Self.result(requested: requested, actual: actual, exitCode: exitCode)
    }
}

private final class MockSleepController: SleepControlling {
    var observedState: Bool?
    var results: [SleepCommandResult]
    var requestedStates: [Bool] = []

    init(observedState: Bool?, results: [SleepCommandResult] = []) {
        self.observedState = observedState
        self.results = results
    }

    func isSleepDisabled() -> Bool? { observedState }

    func setSleepDisabled(_ on: Bool) -> SleepCommandResult {
        requestedStates.append(on)
        return results.removeFirst()
    }

    func isGrantReady() -> Bool { true }
    func isLidClosed() -> Bool { false }
    func battery() -> (level: Double, charging: Bool) { (100, true) }
    func sleepNow() -> Bool { true }
}
