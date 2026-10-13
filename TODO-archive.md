# TODO 归档

（已处理条目的归档；条目正文保留原样可回溯，编号永不复用）

## 🔴 红色

- [ ] **T2**：生产环境跑 `codef` 报错 `execution error: System Events got an error: osascript is not allowed to send keystrokes. (1002)`——运行它的终端 App 没有（或已失效的）辅助功能权限，System Events 发送 Cmd+Ctrl+F 被拒，脚本完全跑不动。处理：系统设置 → 隐私与安全性 → 辅助功能，给终端 App（重新）勾选授权后重跑验证；授权正常仍复现再深入排查（如终端 App 更新后 TCC 权限失效、需要 `-t` 重置）（记录：2026-09-22 12:19）
  ✅**已完成**（完成：2026-09-22 13:20）——根因确认为 Ghostty 分叉为 ad-hoc 签名（无 Team ID），每次重新构建安装后签名哈希变化、TCC 辅助功能授权自动作废。处理：`tccutil reset Accessibility com.mitchellh.ghostty` 清残留失效条目 + 系统设置手动重新授权 Ghostty。最小复现（System Events 窗口枚举）与完整 `codef` 链路均验证通过。根治方案（自签证书进 CI 签名、授权跨构建持续有效）已建 xhqing/ghostty#2 跟踪。验证过程中顺带修复 codef 两个潜伏 bug（activate 撞车 -609 重试、AppleScript handler 路由 -1708 加 `my`），见 CHANGELOG Unreleased。

## 🟡 黄色

- [ ] **T3**：`codef left` 的 Split View 配对在「目标 Code 窗口与终端窗口位于不同 Space」时无法完成（配对点击坐标落在另一个 Space 上），会回退半屏摆放并报错——后续可考虑配对前检测/切换 Space，或给出更明确的提示（记录：2026-10-13 13:45）
  ✅**已放弃**（放弃：2026-10-13 17:58）——用户 2026-10-13 决定不做任何配对相关逻辑：`codef left` 只把 VSCode 摆到左半屏全屏（等价「全屏 → 屏幕左侧」），右侧完全交由用户 / 系统自己处置；「点击跨 Space 失败」这条路径随设计变更整体移除、前提不再存在。（原文曾误编号为 T2、与归档中 2026-09-22 的 T2 重号，归档时修正为 T3。）
