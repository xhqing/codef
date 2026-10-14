# Changelog

All notable changes to this project will be documented in this file.

## [未发布]

### 新增

- **`codef left` 新增「终端全屏预处理」**（2026-10-15，issue #25）：为什么改——承载命令的终端窗口若处于原生全屏（独占一个 Space），触发 VSCode 左半平铺会先与全屏终端形成配对，结果与预期不符（用户需求）。改了什么：① `codef left` 在最开始先判断承载本命令的终端窗口是否处于原生全屏（AXFullScreen），是则先退出其全屏、待其回到普通窗口态后再走原有流程（打开 VSCode → 左半屏平铺）；② 终端 App 识别以 `TERM_PROGRAM` 映射为主（Ghostty / iTerm2 / Terminal / WezTerm / Warp / VSCode 集成终端 / Hyper / kitty / Alacritty / Tabby）；tmux 会把 `TERM_PROGRAM` 覆盖为 `tmux`，此时沿已附加客户端的进程链找外层终端 App；识别不出 / 辅助功能权限缺失 / 退出失败时静默跳过（仅 `CODEF_DEBUG=1` 输出）、不阻塞主流程；③ 退出方式优先直接设置 `AXFullScreen=false`，未生效回退模拟 Ctrl+Cmd+F，轮询确认后再继续；④ 新增桩驱动回归测试（`test/left-terminal-fullscreen.test.sh`，CI 运行）与 README 中英双版说明。

- **`codef left` 终端全屏预处理先行测试（issue #25，测试先行）**：新增 `test/left-terminal-fullscreen.test.sh`——PATH 前置桩驱动 `code` / `osascript`（不触真实系统、不抢屏幕焦点），覆盖：预处理调用形态与位置（脚本第一个 osascript 调用、在帧查询与 `code` 之前、argv 含终端 App bundle id、stdin 含 AXFocusedWindow 读取与 AXMainWindow 兜底、AXFullScreen、非全屏早退、退出尝试 `AXFullScreen=false` 与 Ctrl+Cmd+F 失败回退、轮询）、`TERM_PROGRAM` 映射表十项、未设置 / 未映射与默认模式不发起预处理、五种状态（not-fullscreen / exited / exit-failed / no-app / no-window）best-effort 不阻塞；CI 增加运行步骤。实现尚不存在、测试当前为红；实现与测试同一次提交合入（2026-10-15，Hopper 出题）。

## [0.4.1] - 2026-10-13

### 修复

- **命令命名回退到 `codef` 系列（仅保留新增的 `--version`）**（2026-10-13 用户决定）：项目与命令保持 `codef` 命名，命令共三个——`codef` / `codef left` / `codef --version`；0.4.0 的整批更名（命令 / 仓库 / 目录 / 文档等）回退。改了什么：①脚本文件名、全部用法与报错文案、README 中英双版、`DEVELOPMENT.md`、CI（`--version` 断言改回 `codef x.y.z`）、logo 文字、调试环境变量（回退 `CODEF_DEBUG`）；②GitHub 仓库（`xhqing/codef`）、本地开发目录（`~/Developer/codef`）、xhqing 流量清单与徽章（`traffic/badges/codef.json`）与登记侧（全局注册表映射表 / 分支保护清单）全部回退；③生产副本由 `~/.local/bin/codefs` 换回 `~/.local/bin/codef`。`codef --version` 保留：打印当前版本（与 `VERSION` 一致）。

## [0.4.0] - 2026-10-13

### 新增

- **新增 `codefs --version`**：打印当前版本（输出形如 `codefs 0.4.0`；版本号取自脚本头部 `version:` 行，与仓库根 `VERSION` 一致）；CI 增加「`--version` 输出与 VERSION 一致」断言步骤。

### 变更

- **项目更名 `codef` → `codefs`**（2026-10-13 用户决定）：命令、脚本文件名、GitHub 仓库（`xhqing/codefs`）、本地开发目录（`~/Developer/codefs`）统一更名；README 中英双版、`DEVELOPMENT.md`、CI、logo 文字与调试环境变量（`CODEFS_DEBUG`）同步更新；xhqing 侧流量采集 TEAM 清单与徽章 JSON 同步改名（`traffic/badges/codefs.json`）。生产副本由 `~/.local/bin/codef` 换为 `~/.local/bin/codefs`；旧命令名 `codef` 不再提供；历史条目中的 `codef` 保留原样、不回溯改写。

## [0.3.0] - 2026-10-13

### 变更

- **`codef left` 改为「左半屏全屏」动作（等价于 macOS 的「全屏 → 屏幕左侧」）**（2026-10-13 用户决定，issue #17）。为什么改：自动配对点击方案不可靠（配对界面候选窗口为「散射平铺」、固定坐标在多窗口场景点不中，2026-10-13 实测），用户决定不做配对相关逻辑、只要 VSCode 左半屏全屏，右侧完全交给用户 / 系统自行处理。改了什么：① `codef left` 触发 `Window → Full Screen Tile → Left of Screen`，VSCode 无标题栏独占左半屏，脚本不做任何选择、点击或右侧摆位；② 幂等——目标窗口已是左半全屏时直接返回；原生全屏态先退出全屏再平铺；③ 平铺不可用或未就绪时回退为普通窗口左半屏摆放；④ 移除开发中的 JXA / CGEvent 配对点击、终端窗口自动摆位（TERM_PROGRAM 探测）及相关校验 / 回退逻辑；⑤ CI 移除 JXA 语法检查步骤；⑥ README 中英双版同步新语义；TODO「跨 Space 配对点击失败」条目归档（设计变更后不再适用）。

## [0.2.2] - 2026-10-12

### 变更

- **迁移项目指南到 `DEVELOPMENT.md`，删除智能体专属文件**（2026-10-12 新规）：`CLAUDE.md` / `AGENTS.md` / `.claude/` / `.pi/` 等智能体专属文件不再保留；有价值内容（项目指南 / 上游开发规则等）已迁入普通文档。


### Fixed

- **修复 `codef left` 实机崩溃（2026-10-12 事故，issue #12）**：①**bash 3.2 吞字节**——no-window 提示行的 `「$target_name」` 中 `$var` 后紧跟多字节 `」`，bash 3.2 在 UTF-8 locale 下把该字节吞进变量名（`set -u` 下 unbound variable 整脚本退出）→ 改为 `${target_name}`，CI 增加静态断言（`$var` 后跟非 ASCII 即红）；②**窗口标题匹配**——旧逻辑只认「目录名开头」，而 VSCode 默认标题带活动文件时是「文件名 — 目录名」（实测环境即此形态）、窗口复用时恒不匹配 → 改为按分隔符拆段、逐段去脏标记去空白后与目录名**精确比较**（覆盖纯目录 / 文件前 / 文件后 / em dash / en dash / 连字符 / ● 脏标记，且避免目录名互为子串的误匹配），CI 增加 13 条样例断言（`test/matches-target.applescript`）。

## [0.2.0] - 2026-10-12

### 新增

- **新增 `codef left`：VSCode 左半屏 + 当前终端窗口右半屏并排**（2026-10-12 用户需求，issue #9）。为什么改：用户希望一条命令把 VSCode 与当前终端并排铺满屏幕（原来只有全屏模式）。改了什么：①新增 `left` 关键字参数（`codef left [路径]`；目录名恰好叫 left 时用 `codef ./left`）；②取主屏 `NSScreen.visibleFrame` 精确摆放：终端 App（`TERM_PROGRAM` 映射，默认 Ghostty）的聚焦窗口摆右半屏、VSCode 目标窗口摆左半屏（打开 VSCode 前抓取终端窗口，此时它就是用户刚操作的窗口）；③相关窗口在原生全屏时先退出全屏（原生全屏窗口不能用 AX 摆位）；④终端窗口识别失败时降级为只把 VSCode 放左半屏并告警；默认模式行为不变；⑤CI：AppleScript 语法检查改为循环编译全部 heredoc 块，错误路径补 `codef left` 不存在的目录。

## [0.1.3] - 2026-10-09

### Project

- **同步 Atlas 子项目清单（zcode-cli、cmux-launcher 短期搁置标注）**：为什么改：用户 2026-10-09 决定 zcode-cli 与 cmux-launcher 短期不再维护，Atlas 权威源已作标注，按超集规则本仓库随附版同步。改了什么：随附的 FullStackEngineerAgent CLAUDE.md 全文更新——「目前在手项目」与「当前子项目清单」两处标注两者「自 2026-10-09 起短期搁置」。

## [0.1.2] - 2026-10-09

### Project

- **同步 Atlas 子项目清单（加入 mp4-player）**：为什么改：Atlas 权威源把 mp4-player 登记为新子项目，按超集规则各子项目的随附版需同步。改了什么：随附的 FullStackEngineerAgent CLAUDE.md 全文更新——「目前在手项目」与「当前子项目清单」两处加入 mp4-player。

## [0.1.1] - 2026-10-02

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
