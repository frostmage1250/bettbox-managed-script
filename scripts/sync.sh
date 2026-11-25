#!/usr/bin/env bash
# 抓取上游 Bettbox 托管脚本，并用三方合并把自定义修改重新套上去。
#
#   upstream/managed.js  上次同步时的上游原版（合并基准）
#   managed.js           自定义版（订阅这个文件）
#
# 退出码：0 = 成功或上游无变化；1 = 出错或合并冲突（此时不修改任何文件）。
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://raw.githubusercontent.com/appshubcc/Bettbox/main/assets/scripts/managed.js}"
BASE="upstream/managed.js"
CUSTOM="managed.js"
VERSION_RE='^// @version [0-9]+$'

cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

summary() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$@" >> "$GITHUB_STEP_SUMMARY" || true; }
get_version() { grep -m1 -E "$VERSION_RE" "$1" | awk '{print $3}' || true; }
# 把文件里第一处 "// @version N" 改成指定值
set_version() {
  awk -v v="$2" '!done && /^\/\/ @version [0-9]+$/ { print "// @version " v; done = 1; next } { print }' "$1"
}

curl -fsSL --retry 3 "$UPSTREAM_URL" | tr -d '\r' > "$tmp/new.js"
if [ ! -s "$tmp/new.js" ]; then
  echo "上游脚本为空，放弃同步。" >&2
  exit 1
fi

if cmp -s "$tmp/new.js" "$BASE"; then
  echo "上游没有变化（$(get_version "$BASE")）。"
  exit 0
fi

base_ver="$(get_version "$BASE")"
new_ver="$(get_version "$tmp/new.js")"
echo "上游更新：${base_ver:-?} -> ${new_ver:-?}"

# 先把自定义版的版本号对齐到基准，避免版本号那一行每次都冲突
if [ -n "$base_ver" ]; then
  set_version "$CUSTOM" "$base_ver" > "$tmp/ours.js"
else
  cp "$CUSTOM" "$tmp/ours.js"
fi

set +e
git merge-file -p -L 自定义版 -L 上次的上游 -L 最新上游 "$tmp/ours.js" "$BASE" "$tmp/new.js" > "$tmp/merged.js"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  if [ "$rc" -gt 0 ]; then
    echo "合并冲突：$rc 处。上游改动了你自定义过的地方，需要手动处理。" >&2
    summary "## ❌ 合并冲突（$rc 处）" "" "上游 ${base_ver} -> ${new_ver}，未做任何修改。冲突内容：" "" '```diff'
    { grep -n -A12 '^<<<<<<<' "$tmp/merged.js" | head -200 | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}" >&2; } || true
    summary '```'
  else
    echo "git merge-file 运行出错（$rc）。" >&2
  fi
  exit 1
fi

# 自定义版版本号 = 上游版本号的年份 +1，例如 2026112502 -> 2027112502
if [ -n "$new_ver" ]; then
  custom_ver="$(( ${new_ver:0:4} + 1 ))${new_ver:4}"
  set_version "$tmp/merged.js" "$custom_ver" > "$tmp/final.js"
else
  cp "$tmp/merged.js" "$tmp/final.js"
fi

if command -v node > /dev/null 2>&1; then
  cp "$tmp/final.js" "$tmp/check.js"
  node --check "$tmp/check.js"
else
  echo "未找到 node，跳过语法检查。" >&2
fi

cp "$tmp/final.js" "$CUSTOM"
cp "$tmp/new.js" "$BASE"
echo "已合并，自定义版版本号：${custom_ver:-未变}"
summary "## ✅ 已同步" "" "上游 ${base_ver} -> ${new_ver}，自定义版 ${custom_ver:-未变}"
