#!/usr/bin/env bash
# claude-switch.sh — Claude Code 多套餐切换（bash 版）
# 适用 Git Bash / WSL / Linux / macOS
# 在你的 ~/.bashrc 或 ~/.zshrc 里加一行引用它，例如：
#   source "$HOME/.claude/skills/claude-multi-plan/claude-switch.sh"
#
# 命令：
#   cc / cccc  -> 官方登录 + 允许所有操作
#   ccclaude   -> 官方登录 + 普通
#   cckm       -> Kimi 套餐 + 允许所有操作
#   cckimi     -> Kimi 套餐 + 普通

# ---- Kimi 套餐配置 ----
# key 不写在这里。放到同目录的 claude-switch.local.sh（该文件不上传 GitHub）。
KIMI_BASE_URL="https://api.kimi.com/coding"
KIMI_MODEL="kimi-k2.6"
KIMI_KEY=""   # 由 claude-switch.local.sh 覆盖

# 读取本地私密配置（含 key），存在才加载
# 兼容 bash（BASH_SOURCE）与 zsh（%x），定位本脚本所在目录
if [ -n "${BASH_SOURCE:-}" ]; then
    __cms_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    __cms_src="${(%):-%x}"
else
    __cms_src="$0"
fi
__cms_dir="$(cd "$(dirname "$__cms_src")" && pwd)"
[ -f "$__cms_dir/claude-switch.local.sh" ] && . "$__cms_dir/claude-switch.local.sh"
unset __cms_src

# 切回官方登录态：清掉所有 Kimi 环境变量
_use_claude() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL \
          ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL
}

# 切到 Kimi 套餐（仅当前 shell）
_use_kimi() {
    if [ -z "$KIMI_KEY" ]; then
        echo "[claude-switch] 未配置 Kimi key。请在 claude-switch.local.sh 里设置 KIMI_KEY。" >&2
        return 1
    fi
    export ANTHROPIC_BASE_URL="$KIMI_BASE_URL"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_KEY"
    export ANTHROPIC_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$KIMI_MODEL"
}

# 官方 + 允许所有操作
cc()   { _use_claude; claude --dangerously-skip-permissions "$@"; }
cccc() { _use_claude; claude --dangerously-skip-permissions "$@"; }
# 官方 + 普通
ccclaude() { _use_claude; claude "$@"; }
# Kimi 套餐 + 允许所有操作
cckm() { _use_kimi && claude --dangerously-skip-permissions "$@"; }
# Kimi 套餐 + 普通
cckimi() { _use_kimi && claude "$@"; }
