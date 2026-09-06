import SwiftUI

/// 菜单栏面板：开关 + 模式 + 状态行 + 设置
struct MenuBarPanel: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var durationText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            modeSection
            Divider()
            statusSection
            Divider()
            settingsSection
        }
        .padding(12)
        .frame(width: 300)
        .ululaGlass()
    }

    // MARK: - 头部开关

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: Binding(
                    get: { controller.isKeeping },
                    set: { _ in controller.toggleKeep() }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("保持唤醒").font(.headline)
                        Text(controller.systemStateKnown ? (controller.isKeeping ? "合盖继续运行任务" : "正常睡眠") : "系统状态未知")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(!controller.systemStateKnown || !controller.authReady)
                Spacer()
                if !controller.authReady {
                    Label("未授权", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if let message = controller.safetyMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Label(message, systemImage: controller.systemStateKnown ? "exclamationmark.shield" : "questionmark.diamond")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    if !controller.systemStateKnown {
                        Button("重新检查系统状态") { controller.retrySafetyCheck() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - 模式

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("模式", selection: $settings.mode) {
                Text("无期限").tag(KeepMode.indefinite)
                Text("定时").tag(KeepMode.duration)
                Text("保持到指定时间").tag(KeepMode.targetTime)
            }
            .pickerStyle(.menu)

            if settings.mode == .duration {
                HStack {
                    Text("时长")
                    TextField("分钟", text: $durationText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .onChange(of: durationText) { _, newValue in
                            // 输入合法（1–1440 分钟）才提交，非法输入不生效也不打断
                            guard let v = Int(newValue.trimmingCharacters(in: .whitespaces)),
                                  (1...1440).contains(v) else { return }
                            settings.durationMinutes = v
                            durationText = String(v)
                        }
                        .onChange(of: settings.durationMinutes) { _, newValue in
                            if durationText != String(newValue) {
                                durationText = String(newValue)
                            }
                        }
                    Stepper("", value: $settings.durationMinutes, in: 1...1440, step: 15)
                        .labelsHidden()
                    Spacer()
                }
                .onAppear { durationText = String(settings.durationMinutes) }
            }

            if settings.mode == .targetTime {
                DatePicker("保持到", selection: $settings.targetTime, displayedComponents: .hourAndMinute)
                targetHint
            }
        }
    }

    private var targetHint: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: settings.targetTime)
        let candidate = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: Date()) ?? Date()
        let isTomorrow = candidate <= Date()
        let target = controller.resolvedTarget(settings.targetTime)
        return Text(isTomorrow
                    ? String(format: NSLocalizedString("将保持到明天 %@（已过的时间按次日解释）", comment: ""), AppController.timeString(target))
                    : String(format: NSLocalizedString("将保持到今天 %@", comment: ""), AppController.timeString(target)))
            .font(.caption)
            .foregroundStyle(.orange)
    }

    // MARK: - 状态行

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("状态") {
                Text(controller.systemStateKnown ? (controller.isKeeping ? "保持中" : "正常") : "未知")
                    .foregroundStyle(controller.systemStateKnown ? (controller.isKeeping ? .yellow : .secondary) : .orange)
            }
            LabeledContent("剩余") { Text(controller.remainingText ?? "—").foregroundStyle(.secondary) }
            LabeledContent("电量") {
                Text(String(format: "%.0f%% %@", controller.batteryLevel, controller.charging ? "⚡" : ""))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("盖子") { Text(controller.lidClosed ? "合盖" : "开盖").foregroundStyle(.secondary) }
        }
        .font(.callout)
    }

    // MARK: - 设置

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("开盖自动恢复", isOn: $settings.lidRestoreEnabled)
            Toggle("合盖时锁屏", isOn: $settings.lockOnLidClose)
            if settings.lockOnLidClose && !LockService.isTrusted {
                HStack(spacing: 6) {
                    Label("需要辅助功能权限才能正常锁屏", systemImage: "lock.shield")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("请求权限") { LockService.requestAccessibilityAccess() }
                        .controlSize(.small)
                    Button("打开设置") { LockService.openAccessibilitySettings() }
                        .controlSize(.small)
                }
            }
            Toggle("通知", isOn: $settings.notificationsEnabled)
            Toggle("登录时启动", isOn: $settings.launchAtLogin)
            VStack(spacing: 2) {
                HStack {
                    Text("电量下限")
                    Spacer()
                    Text("\(Int(settings.batteryFloor))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.batteryFloor, in: 5...100, step: 1)
            }
            HStack {
                if !controller.authReady {
                    Button("授权（需管理员密码）") {
                        controller.installAuthorization()
                    }
                } else {
                    Button("重新授权") {
                        controller.installAuthorization()
                    }
                    Button("撤销授权") { controller.revokeAuthorization() }
                }
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
        }
        .font(.callout)
    }
}

extension View {
    /// macOS 26 Liquid Glass，旧系统自动降级
    @ViewBuilder
    func ululaGlass() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular)
        } else {
            self
        }
    }
}
