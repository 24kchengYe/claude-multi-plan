#!/usr/bin/env bash
# install.sh — 把 claude-switch 注入 ~/.bashrc（Git Bash / WSL / Linux / macOS）
# 用法（在 skill 目录下）：  bash install.sh
# zsh 用户：  RC=~/.zshrc bash install.sh

set -e
RC="${RC:-$HOME/.bashrc}"
SCRIPT="$HOME/.claude/skills/claude-multi-plan/claude-switch.sh"
MARKER="claude-multi-plan/claude-switch.sh"

touch "$RC"
if grep -q "$MARKER" "$RC" 2>/dev/null; then
    echo "[skip] 已存在引用: $RC"
else
    {
        echo ""
        echo "# ===== Claude Code 套餐切换（cc/cccc/ccclaude/cckm/cckimi）====="
        echo "source \"$SCRIPT\""
    } >> "$RC"
    echo "[ok]   已注入: $RC"
fi

LOCAL="$(cd "$(dirname "$0")" && pwd)/claude-switch.local.sh"
if [ ! -f "$LOCAL" ]; then
    echo ""
    echo "[!] 还没有 claude-switch.local.sh，请复制 .example 并填入你的 Kimi key："
    echo "    cp \"$(dirname "$0")/claude-switch.local.sh.example\" \"$LOCAL\""
fi
echo ""
echo "完成。重开终端或执行  source $RC  生效。"
