import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

/// 真正的锁屏（等效 ⌃⌘Q 锁定会话，开盖后是带头像的登录窗口）
/// 需要"辅助功能"权限（系统设置 → 隐私与安全性 → 辅助功能）
enum LockService {
    /// 当前是否已获得辅助功能信任
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 请求辅助功能权限，让系统将当前 App 加入可授权列表并显示提示。
    /// 系统权限开关仍必须由用户亲自开启。
    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 锁定当前会话：模拟 ⌃⌘Q
    static func lockNow() {
        guard isTrusted else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        // Q 键 virtual key code = 12
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: true) else { return }
        down.flags = [.maskControl, .maskCommand]
        down.post(tap: .cghidEventTap)
        if let up = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: false) {
            up.flags = [.maskControl, .maskCommand]
            up.post(tap: .cghidEventTap)
        }
    }

    /// 打开辅助功能设置页
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
