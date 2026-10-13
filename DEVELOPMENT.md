# codefs 项目指南

## 负责工程师：Atlas

本项目由 **Atlas**（FullStackEngineerAgent，用户的全栈开发工程师）负责维护。Atlas 负责本项目的全部开发工作——脚本功能迭代、发布流程、生产副本安装。在本项目内的开发 / 维护需求，由 Atlas 统一处理（Atlas 的角色定义与工作原则见 FullStackEngineerAgent 项目根 `CLAUDE.md`）。

codefs 是一个 macOS 终端小工具：全屏打开 VSCode，并保证刚打开的那个窗口就在最上层（`code <dir>` + 自动全屏 + 目标窗口置顶）。bash + osascript 实现，单文件、零依赖。

## 开发目录与生产目录（本项目核心运营规则）

- **开发目录** = 本仓库（`~/Developer/codefs`），一切改动在这里进行；
- **生产目录** = 本机 `~/.local/bin/`（实际运行的 `codefs` 副本所在）；
- **生产副本只能来自正式发版的产物**：改完 → bump 版本 → tag + GitHub Release → 从 Release 产物安装（复制）到 `~/.local/bin/`；**禁止软链开发源码到生产位置、禁止生产环境直跑开发目录脚本**（运行版本与开发版本隔离，全局规则）；
- 版本标识：脚本头部 `# version:` 行与仓库根 `VERSION` 一致；某修复未发版时生产环境就是用不上它，这是隔离的固有代价，不构成跳过发版的理由。

## 工作纪律

- 通用工作规则见全局 `~/.claude/CLAUDE.md`：读取优先、增改查优先慎用删除、汇报前验证、临时产物放 `tmp/`、改动记 `CHANGELOG.md`、待办记 `TODO.md`。
- 本脚本要求运行它的终端 App 有辅助功能权限（macOS 系统设置），改动涉及窗口操作逻辑时注意此前提。


（本文件 2026-10-12 由原 `CLAUDE.md` 的项目指南迁入；按新规，非 Agent 项目不再保留 CLAUDE.md / AGENTS.md 等智能体专属文件。）
