<p align="center">
  <img src="docs/assets/ululawake-app-icon.png" width="128" alt="UlulaWake 应用图标">
</p>

<h1 align="center">UlulaWake</h1>

<p align="center"><strong>让 Mac 合盖后继续运行任务，并在结束后安全恢复正常睡眠。</strong></p>

<p align="center">
  <a href="#系统要求与权限"><img src="https://img.shields.io/badge/platform-macOS%2014%2B-0064e1?style=flat-square" alt="macOS 14+"></a>
  <a href="https://github.com/yingkaisun-kai/ululawake/releases/latest"><img src="https://img.shields.io/github/v/release/yingkaisun-kai/ululawake?style=flat-square&amp;color=2f7de1" alt="最新版本"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/yingkaisun-kai/ululawake?style=flat-square&amp;color=772678" alt="开源许可证"></a>
  <a href="https://github.com/yingkaisun-kai/ululawake/releases"><img src="https://img.shields.io/github/downloads/yingkaisun-kai/ululawake/total?style=flat-square&amp;color=ff6916" alt="累计下载量"></a>
  <a href="https://github.com/yingkaisun-kai/ululawake/actions/workflows/ci.yml"><img src="https://github.com/yingkaisun-kai/ululawake/actions/workflows/ci.yml/badge.svg" alt="CI 状态"></a>
</p>

<p align="center"><a href="README.md">简体中文</a> · <a href="README.en.md">English</a></p>

[下载最新版](https://github.com/yingkaisun-kai/ululawake/releases/latest) · [安全说明](docs/SAFETY.md) · [更新记录](CHANGELOG.md)

## 为什么做 UlulaWake

UlulaWake 是一款 macOS 菜单栏工具，用于下载、构建、训练等需要 Mac 合盖后继续运行的临时任务。它不只开启保持唤醒，还在定时结束、低电量、重新开盖和退出时安全恢复正常睡眠。

## 主要能力

- **三种保持方式**：无限期、倒计时或保持到指定时间。
- **多重自动恢复**：到时、低电量、重新开盖、主动停止或正常退出时恢复睡眠。
- **状态安全检查**：启动时检查异常退出可能留下的保持状态，停止失败时明确提示。
- **可选合盖锁屏**：获得辅助功能权限后锁定当前会话，并可在恢复时发送通知。
- **原生菜单栏体验**：不需要常驻主窗口。

## 下载与快速开始

从 [最新正式版](https://github.com/yingkaisun-kai/ululawake/releases/latest) 下载 DMG，打开后将 `UlulaWake.app` 拖入“应用程序”，再从“应用程序”启动。安装包已经过 Developer ID 签名和 Apple 公证。

1. 点击菜单栏猫头鹰图标，再点击“授权”，通过系统管理员授权启用睡眠控制。
2. 选择保持模式、时长或结束时间，设置电量下限和开盖恢复。
3. 开启保持唤醒；结束任务后关闭，或等待自动恢复。
4. 如需合盖时锁屏，再由你亲自在系统设置中开启辅助功能权限。

## 系统要求与权限

- macOS 14 或更高版本
- Apple silicon 或 Intel Mac
- 改变系统睡眠状态需要一次管理员授权
- 合盖锁屏需要由用户开启可选的“辅助功能”权限

未开启辅助功能时，App 会退回启动屏幕保护程序；**启动屏保不等于已经锁定会话**。合盖运行会受具体硬件和系统设置影响，首次使用请在你的设备上验证完整流程。

## 安全、恢复与卸载

保持唤醒会增加耗电和发热，请保持散热，勿在背包或其他封闭空间中运行。正常退出前，App 会确认系统已经恢复睡眠；失败时会阻止退出。

如无法重新打开 App，可在终端执行：

```sh
sudo pmset -a disablesleep 0
```

卸载前先停止保持唤醒，在菜单中撤销管理员授权，再退出并将 App 移入废纸篓。如曾开启辅助功能或登录时启动，请同时在系统设置中关闭。详见 [安全说明](docs/SAFETY.md)。

## 更新

当前通过 [GitHub Releases](https://github.com/yingkaisun-kai/ululawake/releases/latest) 手动下载正式更新，没有应用内自动更新。

## 数据、网络与隐私

UlulaWake 无需账户，不使用云服务或遥测；设置和运行状态仅保存在本机。

如遇到问题，请前往 [Issues](https://github.com/yingkaisun-kai/ululawake/issues)，附上 UlulaWake 版本、macOS 版本、芯片类型和复现步骤，请勿提交密码或私人数据。

## 从源码构建

需要 Xcode 26 或更高版本（包含 Icon Composer 资源支持）和 XcodeGen：

```sh
brew install xcodegen
./build.sh
./scripts/build-release.sh
```

面向普通用户的 Developer ID 签名、Apple 公证版本请从 [Releases](https://github.com/yingkaisun-kai/ululawake/releases/latest) 下载。

## 开源许可

[Apache License 2.0](LICENSE)。Copyright 2026 Yingkai Sun。
