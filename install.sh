#!/usr/bin/env bash
# install.sh — 把 claude-switch 注入 shell 配置（Git Bash / WSL / Linux / macOS）
# 用法（在 skill 目录下）：  bash install.sh
# 默认按 $SHELL 自动选 ~/.zshrc（macOS 默认）或 ~/.bashrc。
# 手动指定：  RC=~/.zshrc bash install.sh

set -e

# 自动识别目标 rc 文件：macOS 默认 zsh → ~/.zshrc，否则 ~/.bashrc
if [ -z "${RC:-}" ]; then
    case "${SHELL:-}" in
        *zsh) RC="$HOME/.zshrc" ;;
        *)    RC="$HOME/.bashrc" ;;
    esac
fi

# 用本脚本实际所在目录定位 claude-switch.sh（支持 clone 到任意位置）
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DIR/claude-switch.sh"
MARKER="claude-switch.sh"

touch "$RC"
if grep -q "$MARKER" "$RC" 2>/dev/null; then
    echo "[skip] 已存在引用: $RC"
else
    {
        echo ""
        echo "# ===== Claude 套餐切换 + TRAE CLI 模式（cc/cccc/ccclaude/cckm/cckimi/ta/trae/ccta）====="
        echo "source \"$SCRIPT\""
    } >> "$RC"
    echo "[ok]   已注入: $RC"
fi

LOCAL="$DIR/claude-switch.local.sh"
if [ ! -f "$LOCAL" ]; then
    echo ""
    echo "[!] 还没有 claude-switch.local.sh，请复制 .example 并填入你的 Kimi key："
    echo "    cp \"$DIR/claude-switch.local.sh.example\" \"$LOCAL\""
fi
echo ""
echo "完成。重开终端或执行  source $RC  生效。"
