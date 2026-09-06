import Foundation
import os

/// 应用总控制器：开关、安全网（定时/目标时间/电量/开盖）和系统状态对账。
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController(
        sleepController: SleepController.shared,
        settings: SettingsStore.shared,
        notifications: NotificationService.shared,
        authorization: AuthorizationService.shared,
        stateStore: SharedStateStore(),
        runtimeEffects: AppRuntimeEffects()
    )
    private let log = Logger(subsystem: "com.yingkaisun.UlulaWake", category: "app")

    @Published private(set) var isKeeping = false
    @Published private(set) var systemStateKnown = false
    @Published private(set) var safetyMessage: String?
    @Published private(set) var authReady = false
    @Published var lidClosed = false
    @Published var batteryLevel: Double = 100
    @Published var charging = true
    @Published var endDate: Date?

    private var tickTimer: Timer?
    private var auditCounter = 0
    private var lidWasClosed = false
    private var batteryAlerted = false
    private var desiredKeeping = false
    private let sleepController: SleepControlling
    private let safetyCoordinator: SleepSafetyCoordinator
    private let settings: KeepSettingsProviding
    private let notifications: NotificationSending
    private let authorization: AuthorizationServicing
    private let stateStore: AppStatePersisting
    private let runtimeEffects: AppRuntimeEffecting
    private let now: () -> Date

    init(
        sleepController: SleepControlling,
        settings: KeepSettingsProviding,
        notifications: NotificationSending,
        authorization: AuthorizationServicing,
        stateStore: AppStatePersisting,
        runtimeEffects: AppRuntimeEffecting,
        now: @escaping () -> Date = Date.init
    ) {
        self.sleepController = sleepController
        self.safetyCoordinator = SleepSafetyCoordinator(controller: sleepController)
        self.settings = settings
        self.notifications = notifications
        self.authorization = authorization
        self.stateStore = stateStore
        self.runtimeEffects = runtimeEffects
        self.now = now
    }

    func start(scheduleTimer: Bool = true) {
        authReady = sleepController.isGrantReady()
        refreshSensors()
        reconcileOnLaunch()
        if scheduleTimer {
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    // MARK: - 动作

    func toggleKeep() {
        guard systemStateKnown else {
            retrySafetyCheck()
            return
        }
        if isKeeping {
            stopKeep(reason: nil)
        } else {
            startKeep()
        }
    }

    func startKeep() {
        guard authReady else { log.warning("startKeep 被拒：未授权"); return }
        desiredKeeping = true
        let result = safetyCoordinator.enableKeeping()
        applyObservedState(result.actualState)
        guard result.succeeded else {
            desiredKeeping = false
            safetyMessage = failureMessage(action: "开启保持唤醒", result: result)
            log.error("startKeep 失败：\(self.safetyMessage ?? "未知错误", privacy: .public)")
            persistState()
            return
        }
        safetyMessage = nil
        batteryAlerted = false
        endDate = computeEndDate()
        log.info("startKeep mode=\(self.settings.mode.rawValue, privacy: .public) duration=\(self.settings.durationMinutes, privacy: .public) end=\(String(describing: self.endDate), privacy: .public)")
        persistState()
    }

    func stopKeep(reason: String?) {
        desiredKeeping = false
        let result = safetyCoordinator.restoreNormalSleep()
        applyObservedState(result.actualState)
        guard result.actualState == false else {
            safetyMessage = failureMessage(action: "恢复正常睡眠", result: result)
            log.error("stopKeep 失败：\(self.safetyMessage ?? "未知错误", privacy: .public)")
            persistState()
            return
        }
        safetyMessage = nil
        endDate = nil
        log.info("stopKeep reason=\(reason ?? "手动", privacy: .public)")
        if let reason, settings.notificationsEnabled {
            notifications.notifyRestored(reason: reason)
        }
        // 自动恢复（定时/目标时间/电量）且盖子合着时：
        // clamshell 睡眠的触发时机在合盖瞬间已过，空闲睡眠又被后台音乐等断言挡住，
        // 只能主动 sleepnow 强制入睡。延迟 3 秒让通知先送达。
        if reason != nil, sleepController.isLidClosed() {
            runtimeEffects.schedule(after: 3) { [weak self] in
                guard let self, !self.isKeeping else { return }
                self.log.info("stopKeep 合盖中 → pmset sleepnow 强制入睡")
                _ = self.sleepController.sleepNow()
            }
        }
        persistState()
    }

    /// 启动安全策略：不继承旧缓存；若系统仍禁用睡眠，立即尝试恢复。
    private func reconcileOnLaunch() {
        desiredKeeping = false
        endDate = nil
        let result = safetyCoordinator.restoreNormalSleep()
        applyObservedState(result.actualState)
        if result.isConfirmedNormal {
            safetyMessage = nil
            persistState()
        } else {
            safetyMessage = failureMessage(action: "启动时恢复正常睡眠", result: result)
            log.error("启动安全恢复失败：\(self.safetyMessage ?? "未知错误", privacy: .public)")
        }
    }

    func retrySafetyCheck() {
        if desiredKeeping, let actual = sleepController.isSleepDisabled() {
            applyObservedState(actual)
            safetyMessage = actual ? nil : "系统已在 App 外部恢复正常睡眠"
            return
        }
        let result = safetyCoordinator.restoreNormalSleep()
        applyObservedState(result.actualState)
        if result.isConfirmedNormal {
            safetyMessage = nil
            persistState()
        } else {
            safetyMessage = failureMessage(action: "重新检查并恢复正常睡眠", result: result)
        }
    }

    /// App 只有在确认系统已经恢复正常睡眠后才允许退出。
    func prepareForTermination() -> Bool {
        desiredKeeping = false
        let result = safetyCoordinator.restoreNormalSleep()
        applyObservedState(result.actualState)
        guard result.isConfirmedNormal else {
            safetyMessage = failureMessage(action: "退出前恢复正常睡眠", result: result)
            persistState()
            return false
        }
        safetyMessage = nil
        endDate = nil
        persistState()
        return true
    }

    func installAuthorization() {
        if authorization.installGrant() {
            authReady = true
            safetyMessage = nil
            retrySafetyCheck()
        } else {
            authReady = sleepController.isGrantReady()
            safetyMessage = "管理员授权未能完成，请重试"
        }
    }

    func revokeAuthorization() {
        guard prepareForTermination() else { return }
        if authorization.removeGrant() {
            authReady = false
            safetyMessage = "管理员授权已撤销"
        } else {
            authReady = sleepController.isGrantReady()
            safetyMessage = "撤销授权失败，授权规则可能仍然存在"
        }
    }

    /// 模式/时长/目标时间在保持期间变化 → 立即重算结束时间
    func settingsMayAffectKeep() {
        guard isKeeping else { return }
        endDate = computeEndDate()
        log.info("settingsMayAffectKeep 重算 end=\(String(describing: self.endDate), privacy: .public)")
        persistState()
    }

    /// 通知按钮"重新保持"：沿用上次模式立即再开
    func resumeKeep() {
        guard !isKeeping else { return }
        startKeep()
    }

    // MARK: - 模式计算

    private func computeEndDate() -> Date? {
        let s = settings
        switch s.mode {
        case .indefinite:
            return nil
        case .duration:
            return now().addingTimeInterval(TimeInterval(s.durationMinutes * 60))
        case .targetTime:
            return resolvedTarget(s.targetTime)
        }
    }

    /// 目标时间：今天已过则自动解释为次日同一时刻
    func resolvedTarget(_ time: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: time)
        let current = now()
        var candidate = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: current) ?? current
        if candidate <= current {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    var remainingText: String? {
        guard isKeeping, let end = endDate else { return nil }
        let secs = Int(end.timeIntervalSince(now()))
        guard secs > 0 else { return "即将恢复" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 {
            return m > 0 ? "\(h) 小时 \(m) 分" : "\(h) 小时"
        }
        return "\(m) 分 \(s) 秒"
    }

    // MARK: - 每秒 tick（安全网）

    func tick() {
        refreshSensors()
        auditCounter += 1
        if auditCounter >= 5 {
            auditCounter = 0
            auditSystemState()
        }
        guard isKeeping else { return }

        // 兜底：定时/目标时间模式下 endDate 意外为空（如保持期间切换模式的历史 bug）→ 补算
        let s = settings
        if endDate == nil, s.mode != .indefinite {
            endDate = computeEndDate()
            log.info("tick 兜底重算 end=\(String(describing: self.endDate), privacy: .public)")
        }

        if let end = endDate, now() >= end {
            let reason: String
            if s.mode == .targetTime {
                reason = String(format: NSLocalizedString("目标时间 %@ 已到，已恢复睡眠", comment: ""), Self.timeString(end))
            } else {
                reason = NSLocalizedString("定时结束，已恢复睡眠", comment: "")
            }
            stopKeep(reason: reason)
            return
        }

        let batt = sleepController.battery()
        if !batt.charging, batt.level <= settings.batteryFloor, !batteryAlerted {
            batteryAlerted = true
            stopKeep(reason: String(format: NSLocalizedString("电量降至 %.0f%% 以下，已恢复睡眠", comment: ""), settings.batteryFloor))
        }
    }

    private func refreshSensors() {
        let closed = sleepController.isLidClosed()
        if closed != lidWasClosed {
            // 保持唤醒期间合盖：强制显示器正式睡眠，保证开盖时颜色配置重新应用（否则屏幕偏蓝）
            if closed && isKeeping {
                runtimeEffects.forceDisplaySleep()
            }
            if closed && isKeeping && settings.lockOnLidClose {
                runtimeEffects.lockSession()
            }
            if lidWasClosed && !closed && isKeeping && settings.lidRestoreEnabled {
                stopKeep(reason: NSLocalizedString("检测到开盖，自动恢复睡眠", comment: ""))
            }
            lidWasClosed = closed
        }
        lidClosed = closed

        let batt = sleepController.battery()
        batteryLevel = batt.level
        charging = batt.charging
    }

    // MARK: - 系统状态对账

    private func auditSystemState() {
        guard let actual = sleepController.isSleepDisabled() else {
            systemStateKnown = false
            safetyMessage = "无法读取系统睡眠状态，当前状态未知"
            return
        }
        if actual && !desiredKeeping {
            applyObservedState(true)
            safetyMessage = "检测到非预期的保持唤醒状态，正在尝试恢复"
            stopKeep(reason: nil)
            return
        }
        if actual != isKeeping {
            applyObservedState(actual)
            if !actual {
                desiredKeeping = false
                endDate = nil
                safetyMessage = "系统已在 App 外部恢复正常睡眠"
                persistState()
            }
        } else {
            systemStateKnown = true
        }
    }

    private func applyObservedState(_ state: Bool?) {
        guard let state else {
            systemStateKnown = false
            return
        }
        systemStateKnown = true
        isKeeping = state
    }

    private func failureMessage(action: String, result: SleepCommandResult) -> String {
        if let actual = result.actualState {
            return "\(action)失败；系统当前 SleepDisabled=\(actual ? 1 : 0)"
        }
        let detail = result.diagnostic.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "\(action)失败；无法确认系统真实状态" : "\(action)失败：\(detail)"
    }

    // MARK: - 状态持久化（仅记录辅助信息，不作为系统事实源）

    private func persistState() {
        var payload = stateStore.read()
        payload.isKeeping = isKeeping
        payload.mode = settings.mode.rawValue
        payload.endDate = endDate
        payload.batteryLevel = batteryLevel
        payload.charging = charging
        payload.lidClosed = lidClosed
        stateStore.write(payload)
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
