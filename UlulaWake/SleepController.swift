import Foundation

struct SleepCommandResult: Equatable {
    let requestedState: Bool
    let actualState: Bool?
    let commandExitCode: Int32
    let diagnostic: String
    let commandAttempted: Bool

    var succeeded: Bool {
        commandExitCode == 0 && actualState == requestedState
    }

    var isConfirmedNormal: Bool {
        actualState == false
    }

    static func observed(_ state: Bool?) -> SleepCommandResult {
        SleepCommandResult(
            requestedState: false,
            actualState: state,
            commandExitCode: 0,
            diagnostic: "",
            commandAttempted: false
        )
    }
}

protocol SleepControlling {
    func isSleepDisabled() -> Bool?
    func setSleepDisabled(_ on: Bool) -> SleepCommandResult
    func isGrantReady() -> Bool
    func isLidClosed() -> Bool
    func battery() -> (level: Double, charging: Bool)
    func sleepNow() -> Bool
}

/// 把所有“恢复正常睡眠”的判定集中在一处：只有实时读回为 false 才算安全。
final class SleepSafetyCoordinator {
    private let controller: SleepControlling

    init(controller: SleepControlling) {
        self.controller = controller
    }

    func enableKeeping() -> SleepCommandResult {
        controller.setSleepDisabled(true)
    }

    /// 已经确认关闭时不重复执行 sudo；状态为开启或未知时都尝试恢复。
    func restoreNormalSleep() -> SleepCommandResult {
        let observed = controller.isSleepDisabled()
        guard observed != false else { return .observed(false) }
        return controller.setSleepDisabled(false)
    }
}

/// pmset / ioreg 的薄封装：切换 disablesleep、读回状态、传感器（合盖、电量）
final class SleepController: SleepControlling {
    static let shared = SleepController()
    private init() {}

    private func run(_ path: String, _ args: [String]) -> (code: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        do {
            try p.run()
        } catch {
            return (-1, "", "launch failed: \(error.localizedDescription)")
        }
        p.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out, err)
    }

    // MARK: - 核心开关

    /// 当前 SleepDisabled 状态（实时值）
    func isSleepDisabled() -> Bool? {
        SystemProbe.sleepDisabled()
    }

    /// 通过 sudoers 窄规则免密执行 pmset disablesleep
    func setSleepDisabled(_ on: Bool) -> SleepCommandResult {
        let (code, out, err) = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"])
        return SleepCommandResult(
            requestedState: on,
            actualState: isSleepDisabled(),
            commandExitCode: code,
            diagnostic: err.isEmpty ? out : err,
            commandAttempted: true
        )
    }

    /// 授权是否可用：同时验证文件元数据与两条精确命令的 sudoers 匹配。
    func isGrantReady() -> Bool {
        let path = "/etc/sudoers.d/ululawake"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              attrs[.type] as? FileAttributeType == .typeRegular,
              attrs[.ownerAccountName] as? String == "root",
              attrs[.groupOwnerAccountName] as? String == "wheel",
              let permissions = attrs[.posixPermissions] as? NSNumber,
              permissions.intValue == 0o440 else {
            return false
        }
        let off = run("/usr/bin/sudo", ["-n", "-l", "/usr/bin/pmset", "-a", "disablesleep", "0"])
        let on = run("/usr/bin/sudo", ["-n", "-l", "/usr/bin/pmset", "-a", "disablesleep", "1"])
        return off.code == 0 && on.code == 0
    }

    /// 强制立即睡眠（无需 root；无视一切防睡眠断言，包括后台音乐）
    @discardableResult
    func sleepNow() -> Bool {
        let (code, _, _) = run("/usr/bin/pmset", ["sleepnow"])
        return code == 0
    }

    // MARK: - 传感器

    /// 是否合盖（ioreg AppleClamshellState）
    func isLidClosed() -> Bool {
        SystemProbe.isLidClosed()
    }

    /// 电量（百分比）与是否充电
    func battery() -> (level: Double, charging: Bool) {
        SystemProbe.battery()
    }
}
