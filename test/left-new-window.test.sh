#!/bin/bash
# Issue #28 先行用例：codef left「同目录已有左半平铺时另开新窗接管」（测试先行，实现落地前应为红）。
#
# 契约来源：codef Issue #28 与出题条目 T13（Hopper TODO，2026-10-16 17:26）。
#   1) 环境覆盖：别名根目录用 `CODEF_ALIAS_ROOT`（默认 `$HOME/Library/Caches/codef/aliases`）；
#      测试设置该变量到沙箱目录。
#   2) 触发：left 模式第一遍主 AppleScript 返回 `splitview-already` + 第二行旧窗口名时，
#      脚本执行「新窗流程」：
#      a) 在 `$CODEF_ALIAS_ROOT/<唯一子目录>/<目标目录名>` 建符号链接指向目标目录
#         （readlink 等于目标目录 realpath）；
#      b) 再次调用 `code`，参数为别名路径（≠ 真实路径、末段名 == 目标目录名）；
#      c) 以 8 参调用主 AppleScript：argv=[目标名, 第二次捕获的 pre 窗口列表, `left-new`,
#         lx, ly, lw, lh, 第一遍返回的旧窗口名]；
#      d) 第二遍 `tile-ready` → 成功文案（含「另开新窗口」语义）；`tile-not-ready` /
#         `tile-failed` → 走既有回退（回退 osascript 调用）+ 诊断日志
#         （`$HOME/Library/Logs/codef.log` 追加、含别名路径）。
#   3) 别名创建失败 → stderr 告警（含「无法创建别名」类文案）且不尝试新窗
#      （维持 splitview-already 旧行为、退出码 0）。
#   4) 非命中路径不受影响：非 left 模式不出现别名相关调用（两次 code / left-new 均无）。
#
# 驱动方式：PATH 前置桩（code / osascript）记录调用轨迹并返回演示输出；
# HOME 与 CODEF_ALIAS_ROOT 均指向沙箱目录（不写真实日志、不碰真实缓存）。
# 用法：bash test/left-new-window.test.sh

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CODEF="$HERE/../codef"
ORIG_PATH="$PATH"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/codef-left-new-window.XXXXXX") || { echo "无法创建临时目录" >&2; exit 1; }
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

# 主屏可视区查询（-l JavaScript）。
case "$joined" in
  *JavaScript*)
    printf '0,0,1728,1079\n'
    exit 0
    ;;
esac

# 主 AppleScript（stdin 含 matchesTarget）：按 argv 里的模式给输出。
case "$stdin" in
  *matchesTarget*)
    case "$joined" in
      *left-new*)
        # 第二遍（left-new）：状态可配置（默认 tile-ready），第二行新窗口名。
        printf '%s\n%s\n%s\n' "${CODEF_STUB_LEFTNEW_LINE1:-tile-ready}" "NEW-WIN-NAME" "diag-stub-line"
        ;;
      *" left "*)
        # 第一遍（left）：同目录已是左半平铺 → splitview-already + 旧窗口名。
        printf 'splitview-already\n%s\n' "${CODEF_STUB_OLDWIN:-OLD-WIN-NAME}"
        ;;
      *)
        printf 'ok:false\nOLD-WIN-NAME\n'
        ;;
    esac
    exit 0
    ;;
esac

# 打开前窗口列表：第 1 次返回 PRE-ONE、第 2 次返回 PRE-TWO（区分两遍捕获）。
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
  mkdir -p "$RUN_DIR/proj28" "$RUN_DIR/home/Library/Logs" "$RUN_TRACE"
  write_stubs "$RUN_DIR/bin"
  printf '\n-- %s\n' "$CASE_NAME"
}

run_left() { # 附加 env 参数经 $@ 传入（调用方须带上 CODEF_ALIAS_ROOT / TERM_PROGRAM）
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" HOME="$RUN_DIR/home" \
    "$CODEF" left "$RUN_DIR/proj28" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
}

run_default() {
  env "$@" PATH="$RUN_DIR/bin:$ORIG_PATH" CODEF_TEST_TRACE="$RUN_TRACE" HOME="$RUN_DIR/home" \
    "$CODEF" "$RUN_DIR/proj28" >"$RUN_DIR/stdout" 2>"$RUN_DIR/stderr"
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

call_nums_stdin() { # $1 = trace、$2 = stdin 标记（grep -F）→ 含该标记的调用序号列表
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

call_nums_with_arg() { # $1 = trace、$2 = 精确参数值 → argv 行精确等于该值的调用序号列表
  local total i out
  total=$(trace_total "$1")
  out=""
  i=1
  while [ "$i" -le "$total" ]; do
    if [ -f "$1/call-$i/argv" ] && grep -q -x -F -- "$2" "$1/call-$i/argv" 2>/dev/null; then
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

case_success() {
  CASE_NAME="left 同目录已平铺：另开新窗成功路径（别名 symlink / 两次 code / 8 参 left-new / 成功文案）"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local real_target
  real_target=$(cd "$RUN_DIR/proj28" && pwd -P)

  local code_nums code1 code2
  code_nums=$(call_nums_with_tool "$RUN_TRACE" code)
  assert_eq "code 被调用两次" "2" "$(count_fields "$code_nums")"
  code1=$(first_num "$code_nums")
  code2=$(printf '%s' "$code_nums" | awk '{print $2}')
  if [ -n "${code1:-}" ] && [ -n "${code2:-}" ]; then
    assert_eq "第 1 次 code 用真实目录" "$real_target" "$(argv_line "$RUN_TRACE/call-$code1" 1)"
    local alias2
    alias2=$(argv_line "$RUN_TRACE/call-$code2" 1)
    assert_eq "第 2 次 code 末段名 == 目标目录名" "proj28" "$(basename "$alias2")"
    if [ "$alias2" = "$real_target" ]; then
      bad "第 2 次 code 不应复用真实目录路径"
    else
      ok
    fi
    if [ -L "$alias2" ]; then ok; else bad "第 2 次 code 参数应为符号链接（实得「${alias2}」）"; fi
    assert_eq "别名 readlink == 目标目录 realpath" "$real_target" "$(readlink "$alias2" 2>/dev/null)"
    local alias_root_real alias_parent_real
    alias_root_real=$(cd "$RUN_DIR/aliases" 2>/dev/null && pwd -P)
    alias_parent_real=$(cd "$(dirname "$(dirname "$alias2")")" 2>/dev/null && pwd -P)
    assert_eq "别名位于 <root>/<唯一子目录>/<目标名>（父目录直接位于别名根下）" "$alias_root_real" "$alias_parent_real"
  else
    bad "未找到两次 code 调用（code=${code_nums:-无}）"
    return 0
  fi

  local links n_links
  links=$(find "$RUN_DIR/aliases" -type l 2>/dev/null)
  n_links=$(printf '%s\n' "$links" | grep -c .)
  assert_eq "别名根下符号链接恰好 1 个" "1" "$n_links"

  local mains n_main main1 main2
  mains=$(main_call_nums "$RUN_TRACE")
  n_main=$(count_fields "$mains")
  assert_eq "主 AppleScript 调用两次" "2" "$n_main"
  main1=$(first_num "$mains")
  main2=$(printf '%s' "$mains" | awk '{print $2}')
  if [ -n "${main1:-}" ] && [ -n "${main2:-}" ]; then
    assert_eq "第 1 遍 mode=left、pre 为第一次捕获" "left PRE-ONE" "$(argv_line "$RUN_TRACE/call-$main1" 4) $(argv_line "$RUN_TRACE/call-$main1" 3)"
    assert_eq "第 2 遍 argv 个数（含 -）为 9" "9" "$(wc -l < "$RUN_TRACE/call-$main2/argv" | tr -d ' ')"
    assert_eq "第 2 遍 目标名" "proj28" "$(argv_line "$RUN_TRACE/call-$main2" 2)"
    assert_eq "第 2 遍 pre == 第二次捕获（PRE-TWO）" "PRE-TWO" "$(argv_line "$RUN_TRACE/call-$main2" 3)"
    assert_eq "第 2 遍 mode=left-new" "left-new" "$(argv_line "$RUN_TRACE/call-$main2" 4)"
    assert_eq "第 2 遍 lx/ly/lw/lh" "0 0 864 1079" "$(argv_line "$RUN_TRACE/call-$main2" 5) $(argv_line "$RUN_TRACE/call-$main2" 6) $(argv_line "$RUN_TRACE/call-$main2" 7) $(argv_line "$RUN_TRACE/call-$main2" 8)"
    assert_eq "第 8 参 == 第一遍返回的旧窗口名" "OLD-WIN-NAME" "$(argv_line "$RUN_TRACE/call-$main2" 9)"
    if [ "$code2" -gt "$main1" ] && [ "$main2" -gt "$code2" ]; then
      ok
    else
      bad "调用顺序不符（应 main#1 < code#2 < main#2；实得 main1=$main1 code2=$code2 main2=${main2}）"
    fi
  else
    bad "未找到两次主 AppleScript 调用（mains=${mains:-无}）"
  fi

  assert_contains "成功文案含「另开新窗口」" "$(cat "$RUN_DIR/stdout")" "另开新窗口"
}

case_leftnew_failure() { # $1 = left-new 返回首行（tile-not-ready / tile-failed: ...）
  local line1="$1"
  CASE_NAME="left-new 返回「${line1}」：走既有回退 + 诊断日志含别名路径"
  new_run
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases" CODEF_STUB_LEFTNEW_LINE1="$line1"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local code_nums code2 alias2
  code_nums=$(call_nums_with_tool "$RUN_TRACE" code)
  assert_eq "code 仍被调用两次（新窗已开）" "2" "$(count_fields "$code_nums")"
  code2=$(printf '%s' "$code_nums" | awk '{print $2}')
  alias2=$(argv_line "$RUN_TRACE/call-$code2" 1 2>/dev/null)

  assert_eq "回退 osascript 被调用一次" "1" "$(count_fields "$(call_nums_stdin "$RUN_TRACE" "平铺失败收尾")")"

  local log="$RUN_DIR/home/Library/Logs/codef.log"
  if [ -f "$log" ]; then ok; else bad "诊断日志未生成（${log}）"; fi
  if [ -f "$log" ] && [ -n "${alias2:-}" ] && grep -q -F -- "$alias2" "$log"; then
    ok
  else
    bad "诊断日志未包含别名路径「${alias2:-无}」"
  fi
  assert_contains "stderr 提示已回退" "$(cat "$RUN_DIR/stderr")" "回退"
}

case_alias_fail() {
  CASE_NAME="别名创建失败：stderr 告警、不尝试新窗、退出码 0（维持旧行为）"
  new_run
  touch "$RUN_DIR/blocker" # 普通文件占位 → mkdir -p <root>/<sub> 必然失败
  run_left TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/blocker"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local code_nums
  code_nums=$(call_nums_with_tool "$RUN_TRACE" code)
  assert_eq "code 只调用一次（未尝试新窗）" "1" "$(count_fields "$code_nums")"
  assert_eq "主 AppleScript 只调用一次" "1" "$(count_fields "$(main_call_nums "$RUN_TRACE")")"
  assert_eq "无 left-new 模式调用" "0" "$(count_fields "$(call_nums_with_arg "$RUN_TRACE" "left-new")")"

  if grep -Eq '无法创建别名|别名创建失败|创建别名失败' "$RUN_DIR/stderr"; then
    ok
  else
    bad "stderr 未含「无法创建别名」类告警（实得：「$(cat "$RUN_DIR/stderr")」）"
  fi
}

case_default_mode() {
  CASE_NAME="默认模式：不出现别名相关调用（单次 code、无 left-new、无别名 symlink）"
  new_run
  run_default TERM_PROGRAM=ghostty CODEF_ALIAS_ROOT="$RUN_DIR/aliases"
  local rc=$?
  assert_eq "退出码 0" "0" "$rc"

  local code_nums m1
  code_nums=$(call_nums_with_tool "$RUN_TRACE" code)
  assert_eq "code 只调用一次" "1" "$(count_fields "$code_nums")"
  m1=$(first_num "$(main_call_nums "$RUN_TRACE")")
  assert_eq "主 AppleScript 只调用一次" "1" "$(count_fields "$(main_call_nums "$RUN_TRACE")")"
  assert_eq "mode=full" "full" "$(argv_line "$RUN_TRACE/call-${m1:-0}" 4)"
  assert_eq "无 left-new 模式调用" "0" "$(count_fields "$(call_nums_with_arg "$RUN_TRACE" "left-new")")"
  assert_eq "别名根下无符号链接" "0" "$(printf '%s\n' "$(find "$RUN_DIR/aliases" -type l 2>/dev/null)" | grep -c .)"
  if [ -f "$RUN_DIR/home/Library/Logs/codef.log" ]; then
    bad "默认模式不应写诊断日志"
  else
    ok
  fi
}

case_success
case_leftnew_failure "tile-not-ready"
case_leftnew_failure "tile-failed: [stub]"
case_alias_fail
case_default_mode

printf '\n================ 汇总 ================\n'
printf '通过 %d 项，失败 %d 项\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '结果: 红（先行用例在实现落地前应红；实现落地后应全绿）\n'
  exit 1
fi
printf '结果: 全绿\n'
exit 0