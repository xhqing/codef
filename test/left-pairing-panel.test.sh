#!/bin/bash
# Issue #24 收尾先行用例：codef left「残留配对面板」自动清理（测试先行，实现落地前应为红）。
#
# 契约来源：codef Issue #24 评论 + T14 出题条目（Hopper TODO，2026-10-18 23:09）。
#   macOS Tahoe「全屏幕平铺 → 屏幕左侧」成功后会启动「选右半屏伙伴」配对会话
#   （Dock 的 half-backdrop 面板）；会话残留时后续左半平铺被系统静默忽略。
#   修复：触发前用 CGWindowList 预检该面板，命中则自动 Esc 取消 + 再探测。
#
#   1) 预检时机/位置：left 模式「终端全屏预处理 → 屏幕帧查询」之后、「打开前窗口
#      列表 / code 调用」之前，执行一次配对面板探测：`osascript -l JavaScript -e '<JXA>'`，
#      JXA 文本含 `CGWindowListCopyWindowInfo` 与字面量 `half-backdrop`，输出 yes / no
#      （非零退出 / 空输出按「无面板」容错、不阻塞流程）。
#   2) 命中 yes → 发送一次 Esc：`osascript -e 'tell application "System Events" to key code 53'`
#      （argv 含 `key code 53`）→ 短暂等待后再探测一次：第二次 no = cleared；仍 yes =
#      clear-failed；首探即 no / 探测失败 = absent（不发 Esc、无第二次探测）。
#   3) left-new 第二遍（同目录已有左半平铺、另开新窗接管）在第二遍主 AppleScript 调用
#      之前再跑同一套预检。
#   4) tile-not-ready / tile-failed 时 stderr 追加提示：cleared → 含「已自动清除残留的
#      配对面板」；clear-failed → 含「未能自动清除」与「Esc」；absent → 不加。
#   5) 失败日志（$HOME/Library/Logs/codef.log）在 dir: 行后新增一行
#      `pairing-panel: absent|cleared|clear-failed`（left-new 取最后一次预检结果）。
#   6) 默认模式（非 left）不执行任何预检 / 清理动作。
#
# 驱动方式：PATH 前置桩（code / osascript）记录调用轨迹并返回演示输出；
# HOME 与 CODEF_ALIAS_ROOT 均指向沙箱目录（不写真实日志、不碰真实缓存、
# 不发送任何真实 Esc —— 全部由桩承接）。用法：bash test/left-pairing-panel.test.sh

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CODEF="$HERE/../codef"
ORIG_PATH="$PATH"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/codef-pairing-panel.XXXXXX") || { echo "无法创建临时目录" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
CASE_NAME="(setup)"
RUN_SEQ=0
RUN_DIR=""
RUN_TRACE=""

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL [%s] %s\n' "$CASE_NAME" "$1"; }

assert_eq() { # $1 描述、$2 期望、$3 实际
  if [ "$2" = "$3" ]; then
    ok
  else
    bad "$1（期望「$2」，实得「$3」）"
  fi
}

assert_contains() { # $1 描述、$2 全文、$3 片段
  case "$2" in
  *"$3"*) ok ;;
  *) bad "$1（缺少「$3」）" ;;
  esac
}

assert_not_contains() { # $1 描述、$2 全文、$3 片段
  case "$2" in
  *"$3"*) bad "$1（不应含「$3」）" ;;
  *) ok ;;
  esac
}

# —— 桩与轨迹 ——

write_stubs() { # $1 = 放桩的 bin 目录（轨迹写到 ${CODEF_TEST_TRACE}）
  local bin_dir="$1"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/osascript" <<'STUB_OSASCRIPT'
#!/bin/bash
# osascript 桩：记录调用（argv + stdin），按调用形态返回演示输出；不触真实系统。
set -u
trace="${CODEF_TEST_TRACE:?CODEF_TEST_TRACE 未设置}"
mkdir -p "$trace"
idx_file="$trace/index"
if [ -f "$idx_file" ]; then n=$(cat "$idx_file"); else n=0; fi
n=$((n + 1))
printf '%s' "$n" > "$idx_file"
d="$trace/call-$n"
mkdir -p "$d"
printf 'osascript' > "$d/tool"
printf '%s\n' "$@" > "$d/argv"
stdin=""
if [ ! -t 0 ]; then stdin=$(cat); fi
printf '%s' "$stdin" > "$d/stdin"
joined=""
for a in "$@"; do joined="$joined $a"; done

# 终端全屏预处理调用：argv 含任一已知 bundle id。
case "$joined" in
  *com.mitchellh.ghostty*|*com.googlecode.iterm2*|*com.apple.Terminal*|*com.github.wez.wezterm*|*dev.warp.Warp-Stable*|*com.microsoft.VSCode*|*co.zeit.hyper*|*net.kovidgoyal.kitty*|*org.alacritty*|*org.tabby*)
    printf 'exited\n'
    exit 0
    ;;
esac

# 配对面板探测（T14 契约）：按 CODEF_STUB_PANEL_SEQ 依次给 yes / no；
# CODEF_STUB_PANEL_MODE=fail-exit（非零退出）或 empty（空输出）模拟探测失败。
case "$joined" in
  *half-backdrop*)
    if [ "${CODEF_STUB_PANEL_MODE:-}" = "fail-exit" ]; then
      exit 1
    fi
    if [ "${CODEF_STUB_PANEL_MODE:-}" = "empty" ]; then
      exit 0
    fi
    pf="$trace/panelcount"
    if [ -f "$pf" ]; then pn=$(cat "$pf"); else pn=0; fi
    pn=$((pn + 1))
    printf '%s' "$pn" > "$pf"
    val=""
    i=1
    for v in ${CODEF_STUB_PANEL_SEQ:-no}; do
      val="$v"
      if [ "$i" -eq "$pn" ]; then break; fi
      i=$((i + 1))
    done
    printf '%s\n' "$val"
    exit 0
    ;;
esac

# Esc 取消（T14 契约）：记录调用、成功返回。
case "$joined" in
  *"key code 53"*)
    exit 0
    ;;
esac

# 主屏可视区查询（-l JavaScript + NSScreen）。
case "$joined" in
  *NSScreen*)
    printf '0,0,1728,1079\n'
    exit 0
    ;;
esac

# 主 AppleScript（stdin 含 matchesTarget）：按 argv 里的模式给输出。
case "$stdin" in
  *matchesTarget*)
    case "$joined" in
      *left-new*)
        printf '%s\n%s\n%s\n' "${CODEF_STUB_LEFTNEW_LINE1:-tile-ready}" "NEW-WIN-NAME" "diag-stub-line"
        ;;
      *" left "*)
        if [ "${CODEF_STUB_MAIN1_LINE1:-tile-ready}" = "splitview-already" ]; then
          printf 'splitview-already\n%s\n' "OLD-WIN-NAME"
        else
          printf '%s\n%s\n' "${CODEF_STUB_MAIN1_LINE1:-tile-ready}" "WIN-NAME"
        fi
        ;;
      *)
        printf 'ok:false\nWIN-NAME\n'
        ;;
    esac
    exit 0
    ;;
esac

# 打开前窗口列表：第 1 次返回 PRE-ONE、第 2 次返回 PRE-TWO。
case "$stdin" in
  *'exists process "Code"'*)
    pf="$trace/precount"
    if [ -f "$pf" ]; then pn=$(cat "$pf"); else pn=0; fi
    pn=$((pn + 1))
    printf '%s' "$pn" > "$pf"
    case "$pn" in
      1) printf 'PRE-ONE\n' ;;
      2) printf 'PRE-TWO\n' ;;
      *) printf 'PRE-LATER\n' ;;
    esac
    exit 0
    ;;
esac

# 平铺失败收尾回退：返回成功。
case "$stdin" in
  *平铺失败收尾*) printf 'fallback-done\n'; exit 0 ;;
esac

exit 0
STUB_OSASCRIPT

  cat > "$bin_dir/code" <<'STUB_CODE'
#!/bin/bash
# code 桩：记录调用后直接成功返回，不打开任何窗口。
set -u
trace="${CODEF_TEST_TRACE:?CODEF_TEST_TRACE 未设置}"
mkdir -p "$trace"
idx_file="$trace/index"
if [ -f "$idx_file" ]; then n=$(cat "$idx_file"); else n=0; fi
n=$((n + 1))
printf '%s' "$n" > "$idx_file"
d="$trace/call-$n"
mkdir -p "$d"
printf 'code' > "$d/tool"
printf '%s\n' "$@" > "$d/argv"
printf '' > "$d/stdin"
exit 0
STUB_CODE

  chmod +x "$bin_dir/osascript" "$bin_dir/code"
}

new_run() { # 开一次干净运行：沙箱（bin + trace + 目标目录 + HOME 日志目录）
  RUN_SEQ=$((RUN_SEQ + 1))
  RUN_DIR="$WORK/run-$RUN_SEQ"
  RUN_TRACE="$RUN_DIR/trace"
  mkdir -p "$RUN_DIR/proj24" "$RUN_DIR/home/Library/Logs" "$RUN_TRACE"
  write_stubs "$RUN_DIR/bin"
  printf '\n-- %s\n' "$CASE_NAME"
}

run_left() { # 附加 env 参数经 $@ 传入（调用方须带 TERM_PROGRAM / CODEF_ALIAS_ROOT / 桩配置）
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" HOME="$RUN_DIR/home" \
    "$CODEF" left "$RUN_DIR/proj24" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
}

run_default() {
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" HOME="$RUN_DIR/home" \
    "$CODEF" "$RUN_DIR/proj24" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
}

# —— 轨迹查询 ——

trace_total() { # $1 = trace 目录 → 调用总数
  if [ -f "$1/index" ]; then cat "$1/index"; else printf '0'; fi
}

call_argv_text() { tr '\n' ' ' < "$1/argv"; }
call_stdin_text() { cat "$1/stdin" 2>/dev/null; }
call_tool_name() { cat "$1/tool" 2>/dev/null; }
argv_line() { sed -n "$2p" "$1/argv" 2>/dev/null; } # $1 = call 目录、$2 = 行号

count_fields() { # $1 = 空格分隔列表 → 字段数（空串为 0）
  set -- $1
  printf '%s' "$#"
}

first_num() { # $1 = 空格分隔列表 → 第一个字段
  for x in $1; do
    printf '%s' "$x"
    return 0
  done
  return 1
}

nth_num() { # $1 = 空格分隔列表、$2 = 序号（1 起）
  printf '%s' "$1" | awk -v k="$2" '{print $k}'
}

count_grep() { # $1 = 文件、$2 = 固定模式 → 命中行数（文件缺失为 0）
  if [ -f "$1" ]; then
    grep -c -F -- "$2" "$1" 2>/dev/null || true
  else
    printf '0'
  fi
}

call_nums_with_tool() { # $1 = trace、$2 = 工具名
  local total i out
  total=$(trace_total "$1")
  out=""
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/tool" ] && [ "$(call_tool_name "$1/call-$i")" = "$2" ]; then
      out="$out $i"
    fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

call_nums_argv() { # $1 = trace、$2 = argv 标记（grep -F）→ argv 含该标记的调用序号列表
  local total i out
  total=$(trace_total "$1")
  out=""
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/argv" ] && grep -q -F -- "$2" "$1/call-$i/argv" 2>/dev/null; then
      out="$out $i"
    fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

call_nums_stdin() { # $1 = trace、$2 = stdin 标记（grep -F）→ stdin 含该标记的调用序号列表
  local total i out
  total=$(trace_total "$1")
  out=""
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/stdin" ] && grep -q -F -- "$2" "$1/call-$i/stdin" 2>/dev/null; then
      out="$out $i"
    fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

main_call_nums() { # $1 = trace → stdin 含 matchesTarget 的调用序号列表
  call_nums_stdin "$1" "matchesTarget"
}

# —— 用例 ——

case_cleared() {
  CASE_NAME="残留面板 yes→no：探测→Esc→再探测（顺序/次数），tile-not-ready 提示「已自动清除」+ 日志 cleared"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_PANEL_SEQ="yes no" CODEF_STUB_MAIN1_LINE1="tile-not-ready"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local probes escs frames
  probes=$(call_nums_argv "$RUN_TRACE" "half-backdrop")
  escs=$(call_nums_argv "$RUN_TRACE" "key code 53")
  frames=$(call_nums_argv "$RUN_TRACE" "NSScreen")
  assert_eq "探测恰 2 次" "2" "$(count_fields "$probes")"
  assert_eq "Esc 恰 1 次" "1" "$(count_fields "$escs")"

  local p1 p2 e1 f1
  p1=$(nth_num "$probes" 1)
  p2=$(nth_num "$probes" 2)
  e1=$(nth_num "$escs" 1)
  f1=$(nth_num "$frames" 1)
  if [ -n "${f1:-}" ] && [ -n "${p1:-}" ] && [ -n "${e1:-}" ] && [ -n "${p2:-}" ] && [ "$f1" -lt "$p1" ] && [ "$p1" -lt "$e1" ] && [ "$e1" -lt "$p2" ]; then
    ok
  else
    bad "顺序应为 帧查询<探测1<Esc<探测2（实得 f=${f1:-无} p1=${p1:-无} e=${e1:-无} p2=${p2:-无}）"
  fi

  local pre1 code1 m1
  pre1=$(first_num "$(call_nums_stdin "$RUN_TRACE" 'exists process "Code"')")
  code1=$(first_num "$(call_nums_with_tool "$RUN_TRACE" code)")
  m1=$(first_num "$(main_call_nums "$RUN_TRACE")")
  if [ -n "${p2:-}" ] && [ -n "${pre1:-}" ] && [ -n "${code1:-}" ] && [ -n "${m1:-}" ] && [ "$p2" -lt "$pre1" ] && [ "$p2" -lt "$code1" ] && [ "$code1" -lt "$m1" ]; then
    ok
  else
    bad "预检应位于 pre_names / code 之前（p2=${p2:-无} pre=${pre1:-无} code=${code1:-无} main=${m1:-无}）"
  fi

  if [ -n "${p1:-}" ] && [ -n "${e1:-}" ]; then
    assert_contains "探测 JXA 含 CGWindowListCopyWindowInfo" "$(call_argv_text "$RUN_TRACE/call-$p1")" "CGWindowListCopyWindowInfo"
    assert_contains "探测 JXA 含 half-backdrop" "$(call_argv_text "$RUN_TRACE/call-$p1")" "half-backdrop"
    assert_contains "Esc 命令含 key code 53" "$(call_argv_text "$RUN_TRACE/call-$e1")" "key code 53"
  else
    bad "缺少探测 / Esc 调用，无法断言命令文本（p1=${p1:-无} e1=${e1:-无}）"
  fi
  assert_contains "stderr 提示「已自动清除残留的配对面板」" "$(cat "$RUN_DIR/stderr")" "已自动清除残留的配对面板"

  local log="$RUN_DIR/home/Library/Logs/codef.log"
  assert_eq "日志含 pairing-panel: cleared" "1" "$(count_grep "$log" "pairing-panel: cleared")"
  local dline pline
  dline=$(grep -n -F 'dir: ' "$log" 2>/dev/null | head -1 | cut -d: -f1)
  pline=$(grep -n -F 'pairing-panel: ' "$log" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "${dline:-}" ] && [ -n "${pline:-}" ] && [ "$pline" -gt "$dline" ]; then
    ok
  else
    bad "pairing-panel 行应位于 dir: 行之后（dir=${dline:-无} panel=${pline:-无}）"
  fi
  assert_eq "既有回退被调用" "1" "$(count_fields "$(call_nums_stdin "$RUN_TRACE" "平铺失败收尾")")"
}

case_absent_success() {
  CASE_NAME="无面板（首探 no）：不 Esc、无二探、流程照常成功"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "探测恰 1 次" "1" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "无 Esc 调用" "0" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_eq "code 被调用一次" "1" "$(count_fields "$(call_nums_with_tool "$RUN_TRACE" code)")"
  assert_eq "主 AppleScript 被调用一次" "1" "$(count_fields "$(main_call_nums "$RUN_TRACE")")"
  assert_contains "成功文案照常" "$(cat "$RUN_DIR/stdout")" "VSCode 已进入左半屏全屏"
}

case_probe_fail() { # $1 = fail-exit / empty
  local mode="$1"
  CASE_NAME="探测失败（${mode}）：无 Esc、流程照常走完（best-effort）"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_PANEL_MODE="$mode"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "探测恰 1 次" "1" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "无 Esc 调用" "0" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_eq "code 被调用一次" "1" "$(count_fields "$(call_nums_with_tool "$RUN_TRACE" code)")"
  assert_eq "主 AppleScript 被调用一次" "1" "$(count_fields "$(main_call_nums "$RUN_TRACE")")"
}

case_clear_failed() {
  CASE_NAME="残留面板 yes→yes：Esc 后仍在 → tile-not-ready 提示「未能自动清除」+ 日志 clear-failed"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_PANEL_SEQ="yes yes" CODEF_STUB_MAIN1_LINE1="tile-not-ready"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "探测恰 2 次" "2" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "Esc 恰 1 次" "1" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_contains "stderr 含「未能自动清除」" "$(cat "$RUN_DIR/stderr")" "未能自动清除"
  assert_contains "stderr 含「Esc」" "$(cat "$RUN_DIR/stderr")" "Esc"
  local log="$RUN_DIR/home/Library/Logs/codef.log"
  assert_eq "日志含 pairing-panel: clear-failed" "1" "$(count_grep "$log" "pairing-panel: clear-failed")"
  assert_eq "既有回退被调用" "1" "$(count_fields "$(call_nums_stdin "$RUN_TRACE" "平铺失败收尾")")"
}

case_absent_failure() {
  CASE_NAME="无面板（首探 no）+ tile-not-ready：stderr 不加提示、日志 absent"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_MAIN1_LINE1="tile-not-ready"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "探测恰 1 次" "1" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "无 Esc 调用" "0" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_not_contains "stderr 不含已清除提示" "$(cat "$RUN_DIR/stderr")" "已自动清除残留的配对面板"
  assert_not_contains "stderr 不含清除失败提示" "$(cat "$RUN_DIR/stderr")" "未能自动清除"
  assert_eq "日志含 pairing-panel: absent" "1" "$(count_grep "$RUN_DIR/home/Library/Logs/codef.log" "pairing-panel: absent")"
}

case_left_new_two_sets() {
  CASE_NAME="left-new 新窗流程：两遍各一套预检（yes→no ×2），成功文案照常"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_MAIN1_LINE1="splitview-already" CODEF_STUB_PANEL_SEQ="yes no yes no"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_contains "成功文案含「另开新窗口」" "$(cat "$RUN_DIR/stdout")" "另开新窗口"

  local probes escs
  probes=$(call_nums_argv "$RUN_TRACE" "half-backdrop")
  escs=$(call_nums_argv "$RUN_TRACE" "key code 53")
  assert_eq "探测共 4 次（两套）" "4" "$(count_fields "$probes")"
  assert_eq "Esc 共 2 次（两套）" "2" "$(count_fields "$escs")"

  local p1 p2 p3 p4 e1 e2 m1 m2 code2
  p1=$(nth_num "$probes" 1); p2=$(nth_num "$probes" 2); p3=$(nth_num "$probes" 3); p4=$(nth_num "$probes" 4)
  e1=$(nth_num "$escs" 1); e2=$(nth_num "$escs" 2)
  m1=$(nth_num "$(main_call_nums "$RUN_TRACE")" 1)
  m2=$(nth_num "$(main_call_nums "$RUN_TRACE")" 2)
  code2=$(nth_num "$(call_nums_with_tool "$RUN_TRACE" code)" 2)
  if [ -n "${p1:-}" ] && [ -n "${p2:-}" ] && [ -n "${e1:-}" ] && [ "$p1" -lt "$e1" ] && [ "$e1" -lt "$p2" ]; then
    ok
  else
    bad "第一套预检顺序应为 探测1<Esc1<探测2（实得 p1=${p1:-无} e1=${e1:-无} p2=${p2:-无}）"
  fi
  if [ -n "${p3:-}" ] && [ -n "${p4:-}" ] && [ -n "${e2:-}" ] && [ "$p3" -lt "$e2" ] && [ "$e2" -lt "$p4" ]; then
    ok
  else
    bad "第二套预检顺序应为 探测3<Esc2<探测4（实得 p3=${p3:-无} e2=${e2:-无} p4=${p4:-无}）"
  fi
  if [ -n "${m1:-}" ] && [ -n "${p2:-}" ] && [ "$p2" -lt "$m1" ]; then
    ok
  else
    bad "第一套预检应在主 AppleScript 第一遍之前（p2=${p2:-无} m1=${m1:-无}）"
  fi
  if [ -n "${m2:-}" ] && [ -n "${p4:-}" ] && [ "$p4" -lt "$m2" ]; then
    ok
  else
    bad "第二套预检应在第二遍主 AppleScript 之前（p4=${p4:-无} m2=${m2:-无}）"
  fi
  if [ -n "${m1:-}" ] && [ -n "${code2:-}" ] && [ -n "${m2:-}" ] && [ "$m1" -lt "$code2" ] && [ "$code2" -lt "$m2" ]; then
    ok
  else
    bad "新窗流程顺序应为 main#1<code#2<main#2（m1=${m1:-无} code2=${code2:-无} m2=${m2:-无}）"
  fi
}

case_left_new_last_result() {
  CASE_NAME="left-new 失败：日志取最后一次预检结果（absent → clear-failed），stderr 提示清除失败"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_MAIN1_LINE1="splitview-already" CODEF_STUB_LEFTNEW_LINE1="tile-not-ready" CODEF_STUB_PANEL_SEQ="no yes yes"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "探测共 3 次（首套 absent 1 次 + 二套 2 次）" "3" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "Esc 恰 1 次" "1" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_contains "stderr 含「未能自动清除」" "$(cat "$RUN_DIR/stderr")" "未能自动清除"
  local log="$RUN_DIR/home/Library/Logs/codef.log"
  assert_eq "日志 pairing-panel 行唯一" "1" "$(count_grep "$log" "pairing-panel: ")"
  assert_eq "日志取最后一次结果 clear-failed" "1" "$(count_grep "$log" "pairing-panel: clear-failed")"
  assert_eq "既有回退被调用" "1" "$(count_fields "$(call_nums_stdin "$RUN_TRACE" "平铺失败收尾")")"
}

case_default_mode() {
  CASE_NAME="默认模式：不执行任何预检 / 清理动作"
  new_run
  run_default TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_PANEL_SEQ="yes yes"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"
  assert_eq "无探测调用" "0" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "half-backdrop")")"
  assert_eq "无 Esc 调用" "0" "$(count_fields "$(call_nums_argv "$RUN_TRACE" "key code 53")")"
  assert_eq "code 被调用一次" "1" "$(count_fields "$(call_nums_with_tool "$RUN_TRACE" code)")"
  assert_eq "主 AppleScript 被调用一次" "1" "$(count_fields "$(main_call_nums "$RUN_TRACE")")"
}

case_cleared
case_absent_success
case_probe_fail "fail-exit"
case_probe_fail "empty"
case_clear_failed
case_absent_failure
case_left_new_two_sets
case_left_new_last_result
case_default_mode

printf '\n================ 汇总 ================\n'
printf '通过 %d 项，失败 %d 项\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '结果: 红（先行用例在实现落地前应红；实现落地后应全绿）\n'
  exit 1
fi
printf '结果: 全绿\n'
exit 0