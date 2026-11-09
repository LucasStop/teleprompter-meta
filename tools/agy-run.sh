#!/usr/bin/env bash
# Delega uma tarefa ao agy (Gemini 3.8 Flash) em worktree isolado. Uso:
#   tools/agy-run.sh <issue> <slug> <brief.md> [--continue]
# O agy escreve código e roda os gates; commit, push e PR são do Claude (ver AGENTS.md).
set -euo pipefail
issue=${1:?issue}; slug=${2:?slug}; brief=${3:?brief}; cont=${4:-}
repo=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
brief=$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")
branch="$issue-$slug"; wt="$(dirname "$repo")/tp-$issue"
MODEL=${AGY_MODEL:-gemini-3.8-flash-high}
MODE=${AGY_MODE:-accept-edits} # --mode auto não existe nesta conta; se travar em permissão: AGY_SKIP=1
DEST=${DEST:-platform=iOS Simulator,name=iPhone 17}

if [ ! -d "$wt" ]; then
  git -C "$repo" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1 || gh issue develop "$issue" --name "$branch" >/dev/null
  git -C "$repo" fetch -q origin
  git -C "$repo" worktree add -q "$wt" "$branch"
fi
cd "$wt"
mkdir -p docs/agentes && cp -n "$brief" "docs/agentes/$(basename "$brief")" 2>/dev/null || true

args=(-p "$(cat "$brief")" --model "$MODEL" --mode "$MODE" --add-dir "$wt" --output-format text)
[ "${AGY_SKIP:-}" = 1 ] && args+=(--dangerously-skip-permissions)
[ "$cont" = "--continue" ] && args+=(--continue)
agy "${args[@]}"

echo "== git status =="; git status -s
echo "== gates =="
xcodegen generate -q
swiftlint --strict 2>&1 | tail -2
xcodebuild test -scheme Teleprompter -destination "$DEST" -derivedDataPath build.noindex 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head -10
rm -rf build.noindex
