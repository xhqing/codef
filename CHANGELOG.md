# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- **修复 logo 副标题文字被裁切**：`assets/logo.svg` 原副标题 `CLI · Fullscreen VSCode, Target Window On Top`（45 字符、`font-size=22`、起点 `x=230`）实测渲染宽度约 545px，230+545 超出 640 画布宽、文字被直接裁切（渲染像素检测证实文字像素顶到画布右边缘）。改为 `Fullscreen VSCode · On Top`（25 字符），实测文字包围盒回到安全区内、右边距留足。根因与长效防线见 CapabilityManagerAgent CHANGELOG 同日条目（icon-design skill 新增文字边界硬校验 + 校验脚本）。
- **修复 activate 撞车 -609**：`code <dir>` 打开请求刚发出时 VSCode（Electron）主线程忙，紧随的 Apple Event 会被断连（`Connection is invalid (-609)`；实测 code 后立即 activate 稳定复现、延迟后成功）。修复：activate 改为按 bundle id（`com.microsoft.VSCode`，不受按名解析缓存影响）+ 重试循环（最多 6 次、每次间隔 0.25 秒），不用固定 sleep（时序不可靠，初版已知教训）。
- **修复 AppleScript handler 路由 -1708**：在 `tell process "Code"` / `tell application "System Events"` 块内调用脚本级 handler（`matchesTarget` / `raiseViaMenu`），消息会被优先路由给 tell 目标，报 `doesn't understand the message (-1708)`。修复：三处调用加 `my` 前缀强制路由回脚本自身。此为 0.1.0 初版潜伏 bug，此前无环境跑到过该分支。

### Project

- **TODO T2 完成闭环**：辅助功能授权失效（ad-hoc 签名导致）已修复——`tccutil reset` 清残留 + 手动重新授权，最小复现与完整 `codef` 链路均验证通过；根治方案（自签证书进 CI）已建 xhqing/ghostty#2 跟踪。
- **CI 回归防护网上线（PR #1 + PR #2）**：`.github/workflows/ci.yml`（macOS runner，PR 与 main push 均触发），六项检查：bash 语法、shellcheck（warning 档）、AppleScript 语法（heredoc 提取 + osacompile，tell 目标替换为 Finder 以适配无 VSCode 的 runner）、历史 bug 回归断言（-609 / -1708 修复以结构断言锁死）、VERSION 与脚本头版本一致、参数错误路径。断言双向验证：对未修复代码红、对修复代码绿。
- **远端 main 分支保护开启（严肃开发模式）**：禁止直推（含管理员，无 bypass）、required check `test`、合并前分支须最新、仅 squash 合并（repo 层关闭 merge commit / rebase）、禁 force push / 删除、线性历史；auto-merge 已启用，此后一切改动经 PR + CI 绿自动合并。首次启用按防死锁顺序：CI 先经 PR 进 main 并跑绿拿到 check 成功记录，后开保护。

## [0.1.0] - 2026-09-22

### Added

- **codef 命令初版**：`codef [路径]`（默认当前目录）= `code <dir>` + 自动全屏 + 目标窗口置顶（仅 macOS）。修复从 `~/.zshrc` 内嵌函数沿袭而来的三个问题：多窗口时置顶的可能不是目标窗口（`activate` 只激活应用不指定窗口）、固定 `sleep` 时序在窗口创建慢时落空、对已全屏窗口重复按全屏键会误退出全屏。
- 实现要点：打开前记录窗口标题、打开后按标题匹配并优先锁定「本次新增」的窗口；通过点击菜单栏「Window / 窗口」菜单项聚焦目标窗口（跨 Space / 已全屏窗口也能切换过去），菜单不可用时退回 AXRaise；先查 `AXFullScreen` 再决定是否发 Ctrl+Cmd+F。
- `CODEF_DEBUG=1 codef` 输出各阶段调试状态。

### Project

- **建立本仓库（开发目录）**：codef 的开发在 `~/Developer/codef` 进行；`~/.local/bin/codef` 为生产目录副本，发版（tag + GitHub Release）后从 Release 产物安装、两边版本保持一致，禁止软链直跑开发源码（运行版本与开发版本隔离）。
