# TODO

## 🔴 红色

- [ ] **T2**：生产环境跑 `codef` 报错 `execution error: System Events got an error: osascript is not allowed to send keystrokes. (1002)`——运行它的终端 App 没有（或已失效的）辅助功能权限，System Events 发送 Cmd+Ctrl+F 被拒，脚本完全跑不动。处理：系统设置 → 隐私与安全性 → 辅助功能，给终端 App（重新）勾选授权后重跑验证；授权正常仍复现再深入排查（如终端 App 更新后 TCC 权限失效、需要 `-t` 重置）（记录：2026-09-22 12:19）

## 🟡 黄色

- [ ] **T1**：GitHub 仓库上线后，把 `codef` 加进 xhqing 仓库 `scripts/update_traffic.py` 的 TEAM 清单（现在加会导致每日 Action 对不存在的仓库报错），次日确认 README 的 Visitors 徽章正常显示（记录：2026-09-22 12:10）
