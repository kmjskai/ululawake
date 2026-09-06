import Foundation
import AppKit

@MainActor
protocol KeepSettingsProviding: AnyObject {
    var mode: KeepMode { get }
    var durationMinutes: Int { get }
    var targetTime: Date { get }
    var batteryFloor: Double { get }
    var lidRestoreEnabled: Bool { get }
    var notificationsEnabled: Bool { get }
    var lockOnLidClose: Bool { get }
}

protocol NotificationSending: AnyObject {
    func notifyRestored(reason: String)
}

protocol AuthorizationServicing: AnyObject {
    func installGrant() -> Bool
    func removeGrant() -> Bool
}

protocol AppStatePersisting: AnyObject {
    func read() -> UlulaPayload
    func write(_ payload: UlulaPayload)
}

final class SharedStateStore: AppStatePersisting {
    func read() -> UlulaPayload { SharedState.read() }
    func write(_ payload: UlulaPayload) { SharedState.write(payload) }
}

@MainActor
protocol AppRuntimeEffecting: AnyObject {
    func forceDisplaySleep()
    func lockSession()
    func schedule(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void)
}

@MainActor
final class AppRuntimeEffects: AppRuntimeEffecting {
    func forceDisplaySleep() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    func lockSession() {
        if LockService.isTrusted {
            LockService.lockNow()
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "/System/Library/CoreServices/ScreenSaverEngine.app"]
            try? process.run()
        }
    }

    func schedule(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

extension SettingsStore: KeepSettingsProviding {}
extension NotificationService: NotificationSending {}
extension AuthorizationService: AuthorizationServicing {}
