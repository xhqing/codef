#!/bin/bash
# Issue #25 先行用例：codef left「终端全屏预处理」（测试先行，实现落地前应为红）。
#
# 契约来源：GitHub Issue #25 与出题条目 T10（Hopper TODO，2026-10-15 00:05）。
#   (1) left 模式下，预处理是一次独立的 osascript 调用，位于帧查询（-l JavaScript）
#       与 code 调用之前（是脚本的第一个 osascript 调用）；argv 含终端 App 的
#       bundle id；stdin 为 AppleScript 文本，须含：AXFocusedWindow（兜底
#       AXMainWindow）、AXFullScreen、非全屏早退（not-fullscreen）、退出尝试
#       （AXFullScreen 置 false）与失败回退（Ctrl+Cmd+F）及轮询。
#   (2) 终端 App 判定 = TERM_PROGRAM 映射：ghostty→com.mitchellh.ghostty、
#       iTerm.app→com.googlecode.iterm2、Apple_Terminal→com.apple.Terminal、
#       WezTerm→com.github.wez.wezterm、WarpTerminal→dev.warp.Warp-Stable、
#       vscode→com.microsoft.VSCode、Hyper→co.zeit.hyper、kitty→net.kovidgoyal.kitty、
#       Alacritty→org.alacritty、Tabby→org.tabby。
#   (3) TERM_PROGRAM 未设置 / 未映射 → 不发起预处理调用（静默跳过、流程照常）。
#   (4) 默认模式 codef <dir>（非 left）→ 任何情况下不发起预处理调用。
#   (5) 预处理输出五种状态之一（not-fullscreen / exited / exit-failed / no-app /
#       no-window）或静默失败 → best-effort，不阻塞、流程照常走完。
#
# 驱动方式：PATH 前置桩（code / osascript）记录调用轨迹（argv + stdin）并返回
# 演示输出，全程不触真实系统、不抢屏幕焦点。
# 用法：bash test/left-terminal-fullscreen.test.sh

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CODEF="$HERE/../codef"
ORIG_PATH="$PATH"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/codef-left-tfs.XXXXXX") || { echo "无法创建临时目录" >&2; exit 1; }
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
    if [ "${CODEF_STUB_TERM_STATUS+x}" = "x" ]; then
      printf '%s\n' "${CODEF_STUB_TERM_STATUS}"
    else
      printf 'exited\n'
    fi
    exit "${CODEF_STUB_TERM_EXIT:-0}"
    ;;
esac

# 配对面板预检（T14 契约）：既有用例一律视为无面板（no），不触发 Esc。
case "$joined" in
  *half-backdrop*) printf 'no\n'; exit 0 ;;
esac

# 主屏可视区查询（-l JavaScript）。
case "$joined" in
  *JavaScript*)
    printf '0,0,1728,1079\n'
    exit 0
    ;;
esac

# 主 AppleScript（stdin 含 matchesTarget）：按模式给可接受的状态。
case "$stdin" in
  *matchesTarget*)
    case "$joined" in
      *" left "*) printf 'tile-ready\nCode — proj25\n' ;;
      *) printf 'ok:false\nCode — proj25\n' ;;
    esac
    exit 0
    ;;
esac

# 打开前窗口列表（返回空）/ 平铺失败回退（返回成功）。
case "$stdin" in
  *'exists process "Code"'*) exit 0 ;;
  *fallback*) printf 'fallback-done\n'; exit 0 ;;
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

new_run() { # 开一次干净运行：沙箱（bin + trace + 目标目录）
  RUN_SEQ=$((RUN_SEQ + 1))
  RUN_DIR="$WORK/run-$RUN_SEQ"
  RUN_TRACE="$RUN_DIR/trace"
  mkdir -p "$RUN_DIR/proj25" "$RUN_TRACE"
  write_stubs "$RUN_DIR/bin"
  printf '\n-- %s\n' "$CASE_NAME"
}

run_left() { # 附加 env 参数经 $@ 传入（如 -u TERM_PROGRAM / TERM_PROGRAM=ghostty）
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" \
    "$CODEF" left "$RUN_DIR/proj25" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
}

run_default() {
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" \
    "$CODEF" "$RUN_DIR/proj25" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
}

# —— 轨迹查询 ——

trace_total() { # $1 = trace 目录 → 调用总数
  if [ -f "$1/index" ]; then cat "$1/index"; else printf '0'; fi
}

call_argv_text() { tr '\n' ' ' < "$1/argv"; }
call_stdin_text() { cat "$1/stdin" 2>/dev/null; }
call_tool_name() { cat "$1/tool" 2>/dev/null; }

is_known_bundle_arg_text() { # $1 = 拼接后的 argv 文本
  case "$1" in
  *com.mitchellh.ghostty*|*com.googlecode.iterm2*|*com.apple.Terminal*|*com.github.wez.wezterm*|*dev.warp.Warp-Stable*|*com.microsoft.VSCode*|*co.zeit.hyper*|*net.kovidgoyal.kitty*|*org.alacritty*|*org.tabby*)
    return 0
    ;;
  esac
  return 1
}

bundle_call_nums() { # $1 = trace 目录 → argv 含 bundle id 的调用序号（空格分隔）
  local total i out
  total=$(trace_total "$1")
  out=""
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/argv" ] && is_known_bundle_arg_text "$(call_argv_text "$1/call-$i")"; then
      out="$out $i"
    fi
    i=$((i + 1))
  done
  printf '%s' "$out"
}

call_nums_with_tool() { # $1 = trace 目录、$2 = 工具名
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

main_call_num() { # $1 = trace 目录 → stdin 含 matchesTarget 的调用序号
  local total i
  total=$(trace_total "$1")
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/stdin" ] && grep -q 'matchesTarget' "$1/call-$i/stdin" 2>/dev/null; then
      printf '%s' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

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

assert_flow_completed() { # $1 = 标签、$2 = 退出码、$3 = 期望预处理调用数
  assert_eq "$1：退出码 0" "0" "$2"
  assert_eq "$1：预处理调用数" "$3" "$(count_fields "$(bundle_call_nums "$RUN_TRACE")")"
  assert_eq "$1：code 被调用一次" "1" "$(count_fields "$(call_nums_with_tool "$RUN_TRACE" code)")"
  assert_eq "$1：主 AppleScript 被调用一次" "1" "$(count_fields "$(main_call_num "$RUN_TRACE")")"
}

# —— 用例 ——

case_preproc_ghostty() {
  CASE_NAME="left+ghostty：预处理为第一个 osascript 调用、在 code 之前、stdin 含退出逻辑"
  new_run
  run_left TERM_PROGRAM=ghostty
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local nums count first
  nums=$(bundle_call_nums "$RUN_TRACE")
  count=$(count_fields "$nums")
  assert_eq "预处理调用恰好一次" "1" "$count"
  first=$(first_num "$nums")
  assert_eq "预处理是第一个被追踪的调用（call-1）" "1" "${first:-无}"
  if [ -z "${first:-}" ]; then
    bad "未找到含 bundle id 的预处理调用（实现尚不存在时即此处红）"
    return 0
  fi

  assert_eq "预处理调用工具为 osascript" "osascript" "$(call_tool_name "$RUN_TRACE/call-$first")"
  assert_contains "预处理 argv 含 ghostty bundle id" "$(call_argv_text "$RUN_TRACE/call-$first")" "com.mitchellh.ghostty"

  local st
  st=$(call_stdin_text "$RUN_TRACE/call-$first")
  assert_contains "stdin 读取 AXFocusedWindow" "$st" "AXFocusedWindow"
  assert_contains "stdin 有 AXMainWindow 兜底" "$st" "AXMainWindow"
  assert_contains "stdin 读取 AXFullScreen" "$st" "AXFullScreen"
  assert_contains "stdin 含非全屏早退状态 not-fullscreen" "$st" "not-fullscreen"
  assert_contains "stdin 含退出尝试（AXFullScreen 置 false）" "$st" 'set value of attribute "AXFullScreen" of w to false'
  assert_contains "stdin 含失败回退 Ctrl+Cmd+F" "$st" 'keystroke "f" using {command down, control down}'
  assert_contains "stdin 含轮询（repeat）" "$st" "repeat"
  assert_not_contains "预处理脚本与主 AppleScript 独立（不含 matchesTarget）" "$st" "matchesTarget"

  local code_nums code_first main_n
  code_nums=$(call_nums_with_tool "$RUN_TRACE" code)
  assert_eq "code 被调用一次" "1" "$(count_fields "$code_nums")"
  code_first=$(first_num "$code_nums")
  if [ -n "${code_first:-}" ] && [ "$code_first" -gt "$first" ]; then
    ok
  else
    bad "code 调用应在预处理之后（预处理=$first code=${code_first:-无}）"
  fi
  main_n=$(main_call_num "$RUN_TRACE")
  if [ -n "${main_n:-}" ] && [ -n "${code_first:-}" ] && [ "$main_n" -gt "$code_first" ]; then
    ok
  else
    bad "主 AppleScript 调用应在 code 之后（main=${main_n:-无} code=${code_first:-无}）"
  fi
}

case_term_program_mapping() {
  CASE_NAME="TERM_PROGRAM 映射表逐项"
  local pairs pair term bundle rc nums count first
  pairs="ghostty|com.mitchellh.ghostty iTerm.app|com.googlecode.iterm2 Apple_Terminal|com.apple.Terminal WezTerm|com.github.wez.wezterm WarpTerminal|dev.warp.Warp-Stable vscode|com.microsoft.VSCode Hyper|co.zeit.hyper kitty|net.kovidgoyal.kitty Alacritty|org.alacritty Tabby|org.tabby"
  for pair in $pairs; do
    term="${pair%%|*}"
    bundle="${pair#*|}"
    new_run
    run_left TERM_PROGRAM="$term"
    rc=$?
    assert_eq "[$term] 退出码 0" "0" "$rc"
    nums=$(bundle_call_nums "$RUN_TRACE")
    count=$(count_fields "$nums")
    assert_eq "[$term] 预处理调用恰好一次" "1" "$count"
    first=$(first_num "$nums")
    if [ -n "${first:-}" ]; then
      assert_contains "[$term] 预处理 argv 含 $bundle" "$(call_argv_text "$RUN_TRACE/call-$first")" "$bundle"
    else
      bad "[$term] 未找到预处理调用（期望 argv 含 ${bundle}）"
    fi
  done
}

case_skip_unset_and_unmapped() {
  CASE_NAME="TERM_PROGRAM 未设置 → 不发起预处理、流程照常"
  new_run
  run_left -u TERM_PROGRAM
  assert_flow_completed "未设置" "$?" 0

  CASE_NAME="TERM_PROGRAM 未映射 → 不发起预处理、流程照常"
  new_run
  run_left TERM_PROGRAM=unknown-term-xyz
  assert_flow_completed "未映射" "$?" 0
}

case_default_mode_no_preproc() {
  CASE_NAME="默认模式（非 left）→ 任何情况下不发起预处理"
  new_run
  run_default TERM_PROGRAM=ghostty
  assert_flow_completed "默认模式" "$?" 0
}

case_status_best_effort() {
  local st
  for st in not-fullscreen exited exit-failed no-app no-window; do
    CASE_NAME="left+ghostty 预处理状态 $st → best-effort 流程照常"
    new_run
    run_left TERM_PROGRAM=ghostty CODEF_STUB_TERM_STATUS="$st"
    assert_flow_completed "[$st]" "$?" 1
  done

  CASE_NAME="left+ghostty 预处理静默失败（无输出、非零退出）→ 不阻塞流程"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_STUB_TERM_STATUS= CODEF_STUB_TERM_EXIT=1
  assert_flow_completed "静默失败" "$?" 1
}

case_preproc_ghostty
case_term_program_mapping
case_skip_unset_and_unmapped
case_default_mode_no_preproc
case_status_best_effort

printf '\n================ 汇总 ================\n'
printf '通过 %d 项，失败 %d 项\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '结果: 红（先行用例在实现落地前应红；实现落地后应全绿）\n'
  exit 1
fi
printf '结果: 全绿\n'
exit 0
