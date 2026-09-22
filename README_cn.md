<div align="center">
  <img src="assets/logo.svg" alt="codef" width="640">

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)
  [![Version](https://img.shields.io/badge/Version-0.1.0-blue)](CHANGELOG.md)
  [![Type](https://img.shields.io/badge/Type-CLI-4F46E5)](#)
  [![Visitors](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/xhqing/xhqing/main/traffic/badges/codef.json)](https://github.com/xhqing)

  [English](README.md)
</div>

# codef

`codef` 是一个 macOS 终端小工具：**全屏打开 VSCode，并保证刚打开的那个窗口就在最上层**。用法等价于 `code <dir>` + 自动全屏 + 目标窗口置顶。

```bash
codef            # 全屏打开当前目录
codef ~/Developer/blog    # 全屏打开指定目录
```

## 解决什么问题

裸用 `code <dir>` + 模拟全屏快捷键有三个坑，`codef` 逐一修掉：

1. **多窗口时置顶错窗口**：macOS 的 `activate` 只把 VSCode 应用切到前台，不指定哪个窗口在最上层——已有多个窗口时，最上层的可能不是本次要打开的那个。
2. **固定延时时序不可靠**：窗口创建有延迟（冷启动更慢），固定 `sleep` 后发全屏键，慢了就按了个寂寞。
3. **已全屏窗口被误退出全屏**：对已在全屏状态的窗口再按一次 Ctrl+Cmd+F，效果是退出全屏。

## 工作原理

1. 打开前记录 VSCode 现有窗口的标题列表；
2. `code <dir>` 打开（新开窗口或复用已有窗口由 VSCode 决定）；
3. 轮询等目标窗口出现——按窗口标题匹配目录名（VSCode 窗口标题形如「目录名 — 文件名」），并优先锁定「本次打开后新增」的那个窗口，不受同场其他窗口干扰；
4. 点击菜单栏「Window / 窗口」菜单里对应的窗口项把目标窗口带到最前（系统级聚焦语义，目标窗口在**其他 Space 或已全屏**时也能正确切换过去）；菜单不可用时退回 AXRaise；
5. 先查目标窗口的 `AXFullScreen` 属性，**未全屏才**模拟 Ctrl+Cmd+F——不会误退出全屏。

## 安装与前提

- 仅 macOS；依赖 VSCode 自带的 `code` 命令；
- **运行 `codef` 的终端 App 需在「系统设置 → 隐私与安全性 → 辅助功能」中授权**，否则窗口枚举与模拟按键会被系统拒绝（报 `not allowed assistive access`）；
- 安装：把 `codef` 脚本放进 `PATH`（如 `~/.local/bin/`）并加执行权限。

排查问题时可用 `CODEF_DEBUG=1 codef` 输出各阶段状态。

## 开发与生产目录

本仓库是 `codef` 的**开发目录**（`~/Developer/codef`）；**生产目录**为本机 `~/.local/bin/`（实际运行的副本）。两者关系：

- 生产目录的代码**只能来自正式发版的产物**（tag + GitHub Release 后从 Release 下载 / 复制安装），不直跑开发源码、不用软链挂载——运行版本与开发版本严格隔离；
- 两边版本以脚本头部的 `# version:` 行标识，与仓库根 `VERSION` 文件一致，可随时核对生产副本是否落后于已发布版本。

## License & Attribution

Copyright (c) 2026 All Contributors. Released under the [MIT License](LICENSE.md).

Attribution: if you use or reference this project, please keep the copyright notice and credit the source: [codef](https://github.com/xhqing/codef).
