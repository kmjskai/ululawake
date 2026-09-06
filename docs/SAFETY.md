# 权限与安全

UlulaWake 使用系统 `pmset -a disablesleep 1/0` 开启和恢复保持唤醒。
首次授权通过 macOS 管理员授权框，在 `/etc/sudoers.d/ululawake` 写入仅限当前用户、
仅允许这两条精确命令的规则。规则不会读取或保存管理员密码，但授权属于用户级命令授权，
并非只允许 UlulaWake 进程调用；其他以该用户运行的程序也能执行这两条命令。

App 提供撤销入口，撤销前先核对正常睡眠已恢复。直接删除 App 不会撤销此规则。
若 App 无法运行，可先执行 `sudo pmset -a disablesleep 0` 恢复睡眠，
再通过终端移除 `/etc/sudoers.d/ululawake` 这一专用文件；不要删除整个 sudoers 目录。

辅助功能权限用于模拟系统锁屏快捷键。未授权时启动屏幕保护程序，不能保证会话已锁定。
通知权限用于恢复和电量提示，登录时启动由用户自行选择。
设置保存在 UserDefaults，本地状态文件位于 `~/Library/Application Support/UlulaWake/state.json`。
系统实际睡眠状态始终以 pmset 查询结果为准。

自动恢复依赖 App 持续运行。强制结束、崩溃或某些系统故障可能中断恢复；
定时和低电量阈值不是独立于 App 运行的系统保护。保持合盖运行时请保持通风，勿装入背包。
