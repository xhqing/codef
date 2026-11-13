# codef · 项目硬约束

身份与角色见本仓库根 `AGENTS.md`；团队通用规则见全局 `~/.pi/agent/AGENTS.md`，此处不重述。

## 本项目是什么

macOS 终端小工具：全屏打开 VSCode，并保证刚打开的那个窗口在最上层（`code <dir>` + 自动全屏 + 目标窗口置顶）。bash + osascript 实现，单文件、零依赖。

## 硬约束

- **开发目录与生产目录严格隔离**：开发目录是本仓库（`~/Developer/codef`），生产目录是本机 `~/.local/bin/`。
  - **生产副本只能来自正式发版的产物**：改完 → bump 版本 → tag + GitHub Release → 从 Release 产物复制到 `~/.local/bin/`。
身份与角色见本仓库根 `AGENTS.md`；团队通用规则见全局 `~/.pi/agent/AGENTS.md`，此处不重述。
  - 某个修复尚未发版时，生产环境就是用不上它——这是隔离的固有代价，不构成跳过发版的理由。
- **版本号一致**：脚本头部的 `# version:` 行必须与仓库根 `VERSION` 一致（发版时同步改）。
- **窗口 / 焦点类测试绝不在用户工作机上跑**：会抢屏幕焦点、打断用户操作。这类验证要么在专用测试机、要么用 `macmini_run` 去 macmini 上做；本机只跑不碰窗口的检查（语法、`bash -n`、日志解析）。
- **单文件、零依赖**：不引入第三方库，不改造成多文件工程。
- **临时产物放项目 `tmp/`**（已忽略）。

## 调试入口

失败诊断日志在 `~/Library/Logs/codef.log`——`codef left` 触发失败时会追加诊断时间线（屏幕几何、每次尝试的窗口几何 / AXFullScreen / 菜单 enabled / 聚焦窗口、回退结果）。排查失败原因先看它，不要靠猜。

运行本工具要求终端 App 具备辅助功能权限（macOS 系统设置）；改动涉及窗口操作逻辑时把这一点考虑进去。

## 测试文件对 Worker 只读（2026-11-13 立）

测试由 **Leader（dev-agent / Atlas 的会话）在实现开工前**写好，以功能分支上的本地 commit 形式存在。你（Worker）对测试文件**只能读、只能运行**：

- **禁止新建 / 修改 / 删除 / 移动**任何测试文件与测试基础设施：本项目的测试位置是 `test/`（`*.test.sh`）；含 fixtures / helpers / conftest 等伴生文件（跑测试缺了也不自己补）。
- **碰到测试跑不通、断言与 Issue 预期不符 → 终止开发、上报 Leader（`Atlas`）或用户裁决**，绝不改测试迁就实现——这是 LLM 的典型失败模式（改不动代码就放宽断言）。
- **`# TEST_CASES_WRITE_OK` 标记的签发权在 Leader**，你不加；被 `test-cases-guard` 拦下时不要绕过。
- 例外：测试运行自产的缓存与构建产物（`__pycache__`、`.pytest_cache`、coverage 输出、`out/` 等）可清理，走授权标记通道。

## 详细说明

开发与发布约定见项目根 `DEVELOPMENT.md`；通用工作规则见全局 `~/.pi/agent/AGENTS.md`。
