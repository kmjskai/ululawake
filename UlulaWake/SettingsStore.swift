import Foundation
import ServiceManagement

enum KeepMode: String, CaseIterable {
    case indefinite
    case duration
    case targetTime
}

/// 用户设置（持久化到本机 UserDefaults）
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    @Published var mode: KeepMode {
        didSet {
            defaults.set(mode.rawValue, forKey: "set.mode")
            AppController.shared.settingsMayAffectKeep()
        }
    }
    @Published var durationMinutes: Int {
        didSet {
            defaults.set(durationMinutes, forKey: "set.durationMinutes")
            AppController.shared.settingsMayAffectKeep()
        }
    }
    @Published var targetTime: Date {
        didSet {
            defaults.set(targetTime, forKey: "set.targetTime")
            AppController.shared.settingsMayAffectKeep()
        }
    }
    @Published var batteryFloor: Double {
        didSet { defaults.set(batteryFloor, forKey: "set.batteryFloor") }
    }
    @Published var lidRestoreEnabled: Bool {
        didSet { defaults.set(lidRestoreEnabled, forKey: "set.lidRestore") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "set.notifications") }
    }
    @Published var lockOnLidClose: Bool {
        didSet { defaults.set(lockOnLidClose, forKey: "set.lockOnLid") }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    private init() {
        mode = KeepMode(rawValue: defaults.string(forKey: "set.mode") ?? "") ?? .indefinite
        durationMinutes = defaults.object(forKey: "set.durationMinutes") as? Int ?? 120
        let defaultTarget = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
        targetTime = defaults.object(forKey: "set.targetTime") as? Date ?? defaultTarget
        batteryFloor = defaults.object(forKey: "set.batteryFloor") as? Double ?? 15
        lidRestoreEnabled = defaults.object(forKey: "set.lidRestore") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "set.notifications") as? Bool ?? true
        lockOnLidClose = defaults.object(forKey: "set.lockOnLid") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 开发构建未安装到 /Applications 时会失败，静默即可
        }
    }
}
