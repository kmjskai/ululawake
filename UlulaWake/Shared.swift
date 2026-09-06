import Foundation

/// 主 App 的持久化状态。系统是否正在禁用睡眠始终以 pmset 实时值为准，
/// `isKeeping` 仅用于兼容旧状态文件，启动时不会把它当作事实源。
struct UlulaPayload: Codable {
    var isKeeping = false
    var mode = ""
    var endDate: Date?
    var batteryLevel = 100.0
    var charging = true
    var lidClosed = false
}

enum SharedState {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/UlulaWake/state.json")
    }

    static func read() -> UlulaPayload {
        guard let data = try? Data(contentsOf: fileURL) else { return UlulaPayload() }
        return (try? JSONDecoder().decode(UlulaPayload.self, from: data)) ?? UlulaPayload()
    }

    static func write(_ payload: UlulaPayload) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// 系统只读探针（两个 target 共用）：直接执行 pmset / ioreg
enum SystemProbe {
    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return "" }
        p.waitUntilExit()
        return String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// SleepDisabled 实时值；无法读取时返回 nil，不能把探针失败解释成“已恢复”。
    static func sleepDisabled() -> Bool? {
        let out = run("/usr/bin/pmset", ["-g", "live"])
        return parseSleepDisabled(out)
    }

    static func parseSleepDisabled(_ out: String) -> Bool? {
        for line in out.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("SleepDisabled") {
                if trimmed.last == "1" { return true }
                if trimmed.last == "0" { return false }
                return nil
            }
        }
        return nil
    }

    /// 是否合盖
    static func isLidClosed() -> Bool {
        let out = run("/usr/sbin/ioreg", ["-r", "-k", "AppleClamshellState", "-d", "1"])
        for line in out.split(separator: "\n") {
            if line.contains("AppleClamshellState") {
                return line.contains("Yes")
            }
        }
        return false
    }

    /// 电量与充电状态
    static func battery() -> (level: Double, charging: Bool) {
        let out = run("/usr/bin/pmset", ["-g", "batt"])
        var level = 100.0
        let charging = !out.contains("drawing from 'Battery Power'")
        // 注意：必须精确匹配 "NN%"——直接找第一个数字会命中 "InternalBattery-0" 里的 0
        if let range = out.range(of: #"\d+(\.\d+)?(?=%)"#, options: .regularExpression) {
            level = Double(out[range]) ?? 100
        }
        return (level, charging)
    }
}
