-- matchesTarget 样例断言（2026-10-12 事故回归防护）
--
-- 由 CI 把 codef 里的 cleanSegment / matchesTarget 处理器拼在本文件前面再执行：
--   提取处理器 → cat 本文件 → osascript
-- 全部通过 exit 0；任一失败用 error 退出非零（osascript 退出码 1）。
--
-- 覆盖形态：纯目录名 /「文件名 — 目录名」（VSCode 默认带活动文件的标题，
-- 实测用户环境即此形态）/「目录名 — 文件名」/ en dash / 连字符 / 脏标记 ●；
-- 反例：子串形似不得误匹配。
on run
	set fixtures to {}
	set end of fixtures to {"ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"voice-script.md — ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"ExecutiveAssistantAgent — voice-script.md", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"voice-script.md – ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"voice-script.md - ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"● voice-script.md — ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"● ExecutiveAssistantAgent", "ExecutiveAssistantAgent", true}
	set end of fixtures to {"my-ExecutiveAssistantAgent", "ExecutiveAssistantAgent", false}
	set end of fixtures to {"ExecutiveAssistantAgent-notes — foo", "ExecutiveAssistantAgent", false}
	set end of fixtures to {"pre-blog — x", "blog", false}
	set end of fixtures to {"x — blog", "blog", true}
	set end of fixtures to {"● blog", "blog", true}
	set end of fixtures to {"", "blog", false}

	set failures to {}
	repeat with fx in fixtures
		set {winTitle, targetName, expected} to fx
		set got to my matchesTarget(winTitle, targetName)
		if got is not expected then
			set end of failures to (winTitle & " / " & targetName & "：期望 " & expected & " 实得 " & got)
		end if
	end repeat
	if (count of failures) > 0 then
		set joined to ""
		repeat with f in failures
			set joined to joined & linefeed & (f as text)
		end repeat
		error "matchesTarget 样例失败：" & joined
	end if
	return "matchesTarget 样例 " & (count of fixtures) & " 条全部通过"
end run
