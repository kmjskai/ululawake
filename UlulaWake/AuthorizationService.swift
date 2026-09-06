import Foundation

/// 一次性授权：通过系统授权框（管理员密码/Touch ID）安装 sudoers 窄规则。
/// 规则仅允许当前用户以 root 执行两条精确的 pmset 命令，无通配符。
final class AuthorizationService {
    static let shared = AuthorizationService()
    private init() {}

    func installGrant() -> Bool {
        let user = NSUserName()
        guard user.range(of: #"^[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil else {
            return false
        }
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        let tempPath = "/etc/sudoers.d/.ululawake.\(UUID().uuidString).tmp"
        let command = [
            "set -e",
            "umask 077",
            "TMP=\(shellQuote(tempPath))",
            "trap '/bin/rm -f \"$TMP\"' EXIT",
            "/usr/bin/printf '%s\\n' \(shellQuote(rule)) > \"$TMP\"",
            "/usr/sbin/visudo -cf \"$TMP\"",
            "/usr/sbin/chown root:wheel \"$TMP\"",
            "/bin/chmod 0440 \"$TMP\"",
            "/bin/mv -f \"$TMP\" /etc/sudoers.d/ululawake",
            "/usr/sbin/visudo -cf /etc/sudoers",
            "trap - EXIT"
        ].joined(separator: "; ")
        guard runAsAdministrator(command) else { return false }
        return SleepController.shared.isGrantReady()
    }

    func removeGrant() -> Bool {
        let command = "/bin/rm -f /etc/sudoers.d/ululawake; /usr/sbin/visudo -cf /etc/sudoers"
        guard runAsAdministrator(command) else { return false }
        return !FileManager.default.fileExists(atPath: "/etc/sudoers.d/ululawake")
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shellQuote(_ value: String) -> String {
        Self.shellQuote(value)
    }

    private func runAsAdministrator(_ command: String) -> Bool {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"" + escaped + "\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }
}
