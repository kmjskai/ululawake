import XCTest
@testable import UlulaWake

@MainActor
final class AppControllerTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    func testLaunchRestoresResidualStateAndUpdatesUI() {
        let sleep = ControllerMock(
            observedState: true,
            setResults: [result(requested: false, actual: false)]
        )
        let harness = makeHarness(sleep: sleep)

        harness.app.start(scheduleTimer: false)

        XCTAssertTrue(harness.app.systemStateKnown)
        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertNil(harness.app.safetyMessage)
        XCTAssertEqual(sleep.requestedStates, [false])
    }

    func testLaunchRestoreFailureKeepsDangerousStateVisible() {
        let sleep = ControllerMock(
            observedState: true,
            setResults: [result(requested: false, actual: true, exitCode: 1)]
        )
        let harness = makeHarness(sleep: sleep)

        harness.app.start(scheduleTimer: false)

        XCTAssertTrue(harness.app.systemStateKnown)
        XCTAssertTrue(harness.app.isKeeping)
        XCTAssertNotNil(harness.app.safetyMessage)
    }

    func testStopFailureDoesNotClaimRestoredOrNotify() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [
                result(requested: true, actual: true),
                result(requested: false, actual: true, exitCode: 1)
            ]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()

        harness.app.stopKeep(reason: "测试恢复")

        XCTAssertTrue(harness.app.isKeeping)
        XCTAssertNotNil(harness.app.safetyMessage)
        XCTAssertTrue(harness.notifications.reasons.isEmpty)
    }

    func testStartFailureDoesNotEnterKeepingState() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [result(requested: true, actual: false, exitCode: 1)]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)

        harness.app.startKeep()

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertNil(harness.app.endDate)
        XCTAssertNotNil(harness.app.safetyMessage)
    }

    func testTerminationIsBlockedUntilNormalSleepIsConfirmed() {
        let sleep = ControllerMock(
            observedState: true,
            setResults: [result(requested: false, actual: nil, exitCode: 1)]
        )
        let harness = makeHarness(sleep: sleep)

        XCTAssertFalse(harness.app.prepareForTermination())
        XCTAssertFalse(harness.app.systemStateKnown)
        XCTAssertNotNil(harness.app.safetyMessage)
    }

    func testPeriodicAuditRepairsUnexpectedExternalKeepState() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [result(requested: false, actual: false)]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        sleep.observedState = true

        for _ in 0..<5 { harness.app.tick() }

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertEqual(sleep.requestedStates, [false])
    }

    func testPeriodicAuditAcceptsExternalRestoreAndClearsDesiredState() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [result(requested: true, actual: true)]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()
        sleep.observedState = false

        for _ in 0..<5 { harness.app.tick() }

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertNotNil(harness.app.safetyMessage)
        XCTAssertEqual(sleep.requestedStates, [true])
    }

    func testDurationExpiryRestoresThenNotifies() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [
                result(requested: true, actual: true),
                result(requested: false, actual: false)
            ]
        )
        let clock = MutableClock(fixedNow)
        let settings = SettingsMock(mode: .duration, durationMinutes: 15)
        let harness = makeHarness(sleep: sleep, settings: settings, clock: clock)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()
        clock.now = fixedNow.addingTimeInterval(901)

        harness.app.tick()

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertEqual(harness.notifications.reasons.count, 1)
    }

    func testChangingDurationWhileKeepingRecomputesDeadline() {
        let sleep = ControllerMock(
            observedState: false,
            setResults: [result(requested: true, actual: true)]
        )
        let settings = SettingsMock(mode: .duration, durationMinutes: 15)
        let harness = makeHarness(sleep: sleep, settings: settings)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()
        settings.durationMinutes = 30

        harness.app.settingsMayAffectKeep()

        XCTAssertEqual(harness.app.endDate, fixedNow.addingTimeInterval(1_800))
    }

    func testPastTargetTimeResolvesToTheNextDay() {
        let sleep = ControllerMock(observedState: false)
        let harness = makeHarness(sleep: sleep)
        let pastTime = Calendar.current.date(byAdding: .hour, value: -1, to: fixedNow)!

        let resolved = harness.app.resolvedTarget(pastTime)

        XCTAssertGreaterThan(resolved, fixedNow)
        XCTAssertEqual(
            Calendar.current.dateComponents([.hour, .minute], from: resolved),
            Calendar.current.dateComponents([.hour, .minute], from: pastTime)
        )
    }

    func testBatteryFloorRestoresWhenDischarging() {
        let sleep = ControllerMock(
            observedState: false,
            batteryLevel: 10,
            charging: false,
            setResults: [
                result(requested: true, actual: true),
                result(requested: false, actual: false)
            ]
        )
        let settings = SettingsMock(batteryFloor: 15)
        let harness = makeHarness(sleep: sleep, settings: settings)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()

        harness.app.tick()

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertEqual(harness.notifications.reasons.count, 1)
    }

    func testBatteryFloorDoesNotStopWhileCharging() {
        let sleep = ControllerMock(
            observedState: false,
            batteryLevel: 10,
            charging: true,
            setResults: [result(requested: true, actual: true)]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()

        harness.app.tick()

        XCTAssertTrue(harness.app.isKeeping)
        XCTAssertTrue(harness.notifications.reasons.isEmpty)
        XCTAssertEqual(sleep.requestedStates, [true])
    }

    func testAutomaticRestoreWhileLidIsClosedSchedulesImmediateSleep() {
        let sleep = ControllerMock(
            observedState: false,
            lidClosed: true,
            batteryLevel: 10,
            charging: false,
            setResults: [
                result(requested: true, actual: true),
                result(requested: false, actual: false)
            ]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()

        harness.app.tick()
        XCTAssertEqual(harness.runtime.scheduledActions.count, 1)
        harness.runtime.scheduledActions[0]()

        XCTAssertEqual(sleep.sleepNowCount, 1)
    }

    func testOpeningLidRestoresAfterClosedTransition() {
        let sleep = ControllerMock(
            observedState: false,
            lidClosed: false,
            setResults: [
                result(requested: true, actual: true),
                result(requested: false, actual: false)
            ]
        )
        let harness = makeHarness(sleep: sleep)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()
        sleep.lidClosed = true
        harness.app.tick()
        sleep.lidClosed = false

        harness.app.tick()

        XCTAssertFalse(harness.app.isKeeping)
        XCTAssertEqual(harness.notifications.reasons.count, 1)
        XCTAssertEqual(harness.runtime.displaySleepCount, 1)
        XCTAssertEqual(harness.runtime.lockCount, 1)
    }

    func testOpeningLidDoesNotStopWhenRestoreOptionIsDisabled() {
        let sleep = ControllerMock(
            observedState: false,
            lidClosed: false,
            setResults: [result(requested: true, actual: true)]
        )
        let settings = SettingsMock(lidRestoreEnabled: false)
        let harness = makeHarness(sleep: sleep, settings: settings)
        harness.app.start(scheduleTimer: false)
        harness.app.startKeep()
        sleep.lidClosed = true
        harness.app.tick()
        sleep.lidClosed = false

        harness.app.tick()

        XCTAssertTrue(harness.app.isKeeping)
        XCTAssertTrue(harness.notifications.reasons.isEmpty)
        XCTAssertEqual(sleep.requestedStates, [true])
    }

    func testAuthorizationCanBeInstalledAndRevokedOnlyFromSafeState() {
        let sleep = ControllerMock(observedState: false, grantReady: false)
        let authorization = AuthorizationMock(installSucceeds: true, removeSucceeds: true)
        let harness = makeHarness(sleep: sleep, authorization: authorization)

        harness.app.installAuthorization()
        XCTAssertTrue(harness.app.authReady)

        harness.app.revokeAuthorization()
        XCTAssertFalse(harness.app.authReady)
        XCTAssertEqual(authorization.installCount, 1)
        XCTAssertEqual(authorization.removeCount, 1)
    }

    func testAuthorizationRemovalIsBlockedWhenSleepCannotBeRestored() {
        let sleep = ControllerMock(
            observedState: true,
            setResults: [result(requested: false, actual: true, exitCode: 1)]
        )
        let authorization = AuthorizationMock(removeSucceeds: true)
        let harness = makeHarness(sleep: sleep, authorization: authorization)

        harness.app.revokeAuthorization()

        XCTAssertEqual(authorization.removeCount, 0)
        XCTAssertTrue(harness.app.isKeeping)
        XCTAssertNotNil(harness.app.safetyMessage)
    }

    private func makeHarness(
        sleep: ControllerMock,
        settings: SettingsMock? = nil,
        authorization: AuthorizationMock = AuthorizationMock(),
        clock: MutableClock? = nil
    ) -> Harness {
        let notifications = NotificationMock()
        let stateStore = StateStoreMock()
        let runtime = RuntimeMock()
        let effectiveSettings = settings ?? SettingsMock()
        let effectiveClock = clock ?? MutableClock(fixedNow)
        let app = AppController(
            sleepController: sleep,
            settings: effectiveSettings,
            notifications: notifications,
            authorization: authorization,
            stateStore: stateStore,
            runtimeEffects: runtime,
            now: { effectiveClock.now }
        )
        return Harness(
            app: app,
            notifications: notifications,
            stateStore: stateStore,
            runtime: runtime
        )
    }

    private func result(
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
}

@MainActor
private struct Harness {
    let app: AppController
    let notifications: NotificationMock
    let stateStore: StateStoreMock
    let runtime: RuntimeMock
}

private final class MutableClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

private final class SettingsMock: KeepSettingsProviding {
    var mode: KeepMode
    var durationMinutes: Int
    var targetTime: Date
    var batteryFloor: Double
    var lidRestoreEnabled: Bool
    var notificationsEnabled: Bool
    var lockOnLidClose: Bool

    init(
        mode: KeepMode = .indefinite,
        durationMinutes: Int = 120,
        targetTime: Date = Date(timeIntervalSince1970: 0),
        batteryFloor: Double = 15,
        lidRestoreEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        lockOnLidClose: Bool = true
    ) {
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.targetTime = targetTime
        self.batteryFloor = batteryFloor
        self.lidRestoreEnabled = lidRestoreEnabled
        self.notificationsEnabled = notificationsEnabled
        self.lockOnLidClose = lockOnLidClose
    }
}

private final class NotificationMock: NotificationSending {
    var reasons: [String] = []
    func notifyRestored(reason: String) { reasons.append(reason) }
}

private final class AuthorizationMock: AuthorizationServicing {
    let installSucceeds: Bool
    let removeSucceeds: Bool
    var installCount = 0
    var removeCount = 0

    init(installSucceeds: Bool = false, removeSucceeds: Bool = false) {
        self.installSucceeds = installSucceeds
        self.removeSucceeds = removeSucceeds
    }

    func installGrant() -> Bool {
        installCount += 1
        return installSucceeds
    }

    func removeGrant() -> Bool {
        removeCount += 1
        return removeSucceeds
    }
}

private final class StateStoreMock: AppStatePersisting {
    var payload = UlulaPayload()
    var writeCount = 0
    func read() -> UlulaPayload { payload }
    func write(_ payload: UlulaPayload) {
        self.payload = payload
        writeCount += 1
    }
}

@MainActor
private final class RuntimeMock: AppRuntimeEffecting {
    var displaySleepCount = 0
    var lockCount = 0
    var scheduledActions: [@MainActor @Sendable () -> Void] = []

    func forceDisplaySleep() { displaySleepCount += 1 }
    func lockSession() { lockCount += 1 }
    func schedule(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) {
        scheduledActions.append(action)
    }
}

private final class ControllerMock: SleepControlling {
    var observedState: Bool?
    var grantReady: Bool
    var lidClosed: Bool
    var batteryLevel: Double
    var charging: Bool
    var setResults: [SleepCommandResult]
    var requestedStates: [Bool] = []
    var sleepNowCount = 0

    init(
        observedState: Bool?,
        grantReady: Bool = true,
        lidClosed: Bool = false,
        batteryLevel: Double = 100,
        charging: Bool = true,
        setResults: [SleepCommandResult] = []
    ) {
        self.observedState = observedState
        self.grantReady = grantReady
        self.lidClosed = lidClosed
        self.batteryLevel = batteryLevel
        self.charging = charging
        self.setResults = setResults
    }

    func isSleepDisabled() -> Bool? { observedState }

    func setSleepDisabled(_ on: Bool) -> SleepCommandResult {
        requestedStates.append(on)
        let result = setResults.removeFirst()
        observedState = result.actualState
        return result
    }

    func isGrantReady() -> Bool { grantReady }
    func isLidClosed() -> Bool { lidClosed }
    func battery() -> (level: Double, charging: Bool) { (batteryLevel, charging) }
    func sleepNow() -> Bool {
        sleepNowCount += 1
        return true
    }
}
