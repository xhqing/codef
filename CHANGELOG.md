# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- **修复 logo 副标题文字被裁切**：`assets/logo.svg` 原副标题 `CLI · Fullscreen VSCode, Target Window On Top`（45 字符、`font-size=22`、起点 `x=230`）实测渲染宽度约 545px，230+545 超出 640 画布宽、文字被直接裁切（渲染像素检测证实文字像素顶到画布右边缘）。改为 `Fullscreen VSCode · On Top`（25 字符），实测文字包围盒回到安全区内、右边距留足。根因与长效防线见 CapabilityManagerAgent CHANGELOG 同日条目（icon-design skill 新增文字边界硬校验 + 校验脚本）。

### Project

- **TODO 新增 T2**：生产环境跑 `codef` 报错 `osascript is not allowed to send keystrokes (1002)`（终端 App 辅助功能权限缺失 / 失效，System Events 发键被拒），记入 🔴 待办待排查修复；T1（Visitors 徽章脚本清单）为此前已有待办。

## [0.1.0] - 2026-09-22

### Added

- **codef 命令初版**：`codef [路径]`（默认当前目录）= `code <dir>` + 自动全屏 + 目标窗口置顶（仅 macOS）。修复从 `~/.zshrc` 内嵌函数沿袭而来的三个问题：多窗口时置顶的可能不是目标窗口（`activate` 只激活应用不指定窗口）、固定 `sleep` 时序在窗口创建慢时落空、对已全屏窗口重复按全屏键会误退出全屏。
- 实现要点：打开前记录窗口标题、打开后按标题匹配并优先锁定「本次新增」的窗口；通过点击菜单栏「Window / 窗口」菜单项聚焦目标窗口（跨 Space / 已全屏窗口也能切换过去），菜单不可用时退回 AXRaise；先查 `AXFullScreen` 再决定是否发 Ctrl+Cmd+F。
- `CODEF_DEBUG=1 codef` 输出各阶段调试状态。

### Project

- **建立本仓库（开发目录）**：codef 的开发在 `~/Developer/codef` 进行；`~/.local/bin/codef` 为生产目录副本，发版（tag + GitHub Release）后从 Release 产物安装、两边版本保持一致，禁止软链直跑开发源码（运行版本与开发版本隔离）。
