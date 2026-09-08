# UlulaWake

让 Mac 合盖后继续运行任务，并在结束后恢复正常睡眠。

UlulaWake 是一款 macOS 菜单栏工具，适合下载、构建等需要临时保持 Mac 运行的场景。
支持无限期、倒计时和指定结束时间，并提供低电量、重新开盖和退出时的恢复机制。

**系统要求：macOS 14 或更高版本；Apple Silicon 或 Intel Mac。**
当前界面为中文。合盖行为受具体硬件和系统设置影响，首次使用请在你的 Mac 上验证。

## 下载与安装

在 [Releases](https://github.com/yingkaisun-kai/UlulaWake/releases) 下载 DMG，
打开后将 UlulaWake 拖入 Applications，再从 Applications 启动。
正式安装包由 GitHub Actions 构建，并经过 Developer ID 签名和 Apple 公证。

## 开始使用

1. 点击菜单栏猫头鹰图标，点击“授权”，通过系统管理员授权启用睡眠控制。
2. 选择保持模式、时长或结束时间，设置电量下限和开盖恢复选项。
3. 打开保持唤醒开关；结束任务后关闭开关，或等待自动恢复。
4. 如需合盖时锁屏，在“合盖时锁屏”区域先点击“请求权限”，再到辅助功能设置打开开关。

辅助功能权限是锁定会话所需的可选权限，必须由用户在系统设置中启用。
未授权时会退回启动屏幕保护程序；**启动屏保不等于已经锁定会话**。

## 恢复与卸载

保持唤醒会增加耗电和发热，请保持散热，勿在背包或其他封闭空间中运行。
正常退出前，App 会核对系统已经恢复睡眠；失败时会阻止退出并提示处理。
强制结束或崩溃时无法执行退出清理，重新打开 App 会尝试恢复。
如不能重新打开，在终端执行：

```sh
sudo pmset -a disablesleep 0
```

卸载前先停止保持唤醒，在菜单中撤销管理员授权，然后退出并将 App 移入废纸篓。
如曾开启辅助功能或登录时启动，请在系统设置中关闭相关授权与启动项。
仅删除 App 不会自动移除睡眠控制授权。更多权限说明见 [权限与安全](docs/SAFETY.md)。

## 隐私与反馈

无账户、云服务或遥测；设置和状态保存在本机。
问题请提交到 [Issues](https://github.com/yingkaisun-kai/UlulaWake/issues)，
附上版本、macOS 版本、芯片类型与复现步骤，勿附密码或私人数据。
当前通过 Releases 手动下载更新，没有应用内自动更新。

## 从源码构建

需要 Xcode 26 或更高版本（包含 Icon Composer 资源支持）和 XcodeGen。

```sh
brew install xcodegen
./build.sh                 # 本地 Debug 构建
./scripts/test.sh          # 使用模拟控制器的自动测试
./scripts/build-release.sh # 无证书的双架构 Release 构建
```

本地构建不等于已签名公证的正式发行包。发布机制见 [发布说明](docs/RELEASING.md)。

## 开源许可与历史

[Apache License 2.0](LICENSE)。Copyright 2026 Yingkai Sun。
公开仓库按版本提供可构建源码快照；Tag 固定指向对应版本。
main 同时维护最新的使用文档与发布工作流。
开发过程、内部记录和中间提交保留在维护者的开发仓库中。
