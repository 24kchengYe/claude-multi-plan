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
#   ta         -> TRAE CLI + 允许所有操作（bypass_permissions）
#   trae       -> TRAE CLI 普通模式

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

# 切回官方登录态：清掉所有 Kimi 环境变量 + 旧的 API key（避免冲突）
_use_claude() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL \
          ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
          ANTHROPIC_API_KEY
}

# 切到 Kimi 套餐（仅当前 shell）
_use_kimi() {
    if [ -z "$KIMI_KEY" ]; then
        echo "[claude-switch] 未配置 Kimi key。请在 claude-switch.local.sh 里设置 KIMI_KEY。" >&2
        return 1
    fi
    # 先清掉旧的 API key，避免和 AUTH_TOKEN 冲突
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$KIMI_BASE_URL"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_KEY"
    export ANTHROPIC_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$KIMI_MODEL"
}

# 先解除可能存在的同名 alias，避免函数定义语法冲突
unalias cc cccc ccclaude cckm cckimi 2>/dev/null || true

# 官方 + 允许所有操作
cc()   { _use_claude; claude --dangerously-skip-permissions "$@"; }
cccc() { _use_claude; claude --dangerously-skip-permissions "$@"; }
# 官方 + 普通
ccclaude() { _use_claude; claude "$@"; }
# Kimi 套餐 + 允许所有操作
cckm() { _use_kimi && claude --dangerously-skip-permissions "$@"; }
# Kimi 套餐 + 普通
cckimi() { _use_kimi && claude "$@"; }

# ---- TRAE CLI 启动模式（traecli/traex，仅 mac/linux）----
# traex/traecli 装在 ~/.local/bin，ccr/node 装在 ~/.local/bin/node/bin，确保都在 PATH 上
for __d in "$HOME/.local/bin" "$HOME/.local/bin/node/bin"; do
    case ":$PATH:" in
        *":$__d:"*) ;;
        *) [ -d "$__d" ] && export PATH="$__d:$PATH" ;;
    esac
done
unset __d
unalias ta trae 2>/dev/null || true
# 允许所有操作：官方 bypass_permissions 预设（可编辑工作区外文件 + 联网 + 不审批），
# 不用文档不推荐的 -y/--dangerously-bypass-approvals-and-sandbox（那个会完全关沙箱、永不审批）。
ta()   { command traecli --permission-mode bypass_permissions "$@"; }
# 普通模式：默认 Agent 模式，危险操作仍会请求审批
trae() { command traecli "$@"; }

# ---- ccta：Claude Code 跑在 traecli 的内部模型上（经 CCR 反代，Trae CN 网关）----
# cc 说 Anthropic 协议，Trae CN 网关（lcd.bytedance.net/litellm_trae）只开 OpenAI 协议，
# 靠本地 CCR 把 /v1/messages 翻译成 /v1/chat/completions。
# 一键：刷新 trae JWT → 拉起 CCR → 启动 Claude Code + 允许所有操作；默认模型 openrouter-2o。
unalias ccta 2>/dev/null || true
ccta() {
    local jwt
    jwt="$(tr -d '\n' < "$HOME/.trae-cn/trae-jwt-token" 2>/dev/null)"
    if [ -z "$jwt" ]; then
        echo "[ccta] 未找到 ~/.trae-cn/trae-jwt-token，请先用 traecli 登录后再试。" >&2
        return 1
    fi
    _use_claude                          # 清掉 cckm 等残留的 ANTHROPIC_* 变量，避免串味
    export TRAE_CN_JWT="$jwt"            # CCR 配置里 api_key=$TRAE_CN_JWT，启动时注入最新 JWT（约 24h 过期）
    command ccr restart >/dev/null 2>&1  # 用最新 JWT 重启 CCR
    eval "$(command ccr activate)"       # 关键：导出 ANTHROPIC_BASE_URL=127.0.0.1:3456 + token，让 cc 走 CCR
    # 安全护栏：若环境没指向 CCR，立即中止，避免误用真 Anthropic 计费
    if [ "$ANTHROPIC_BASE_URL" != "http://127.0.0.1:3456" ]; then
        echo "[ccta] ANTHROPIC_BASE_URL 未指向本地 CCR（实际：${ANTHROPIC_BASE_URL:-空}）。已中止以防误用真 Anthropic 计费。" >&2
        return 1
    fi
    command claude --dangerously-skip-permissions "$@"
}

# ---- ccta-aiden：Claude Code 跑在 Aiden AIProxy 上（经本地 CCR + aiden-proxy 双桥）----
# Claude Code 发 Anthropic 协议 → CCR(127.0.0.1:3456) 转成 OpenAI 协议 →
# aiden-proxy(127.0.0.1:3457) 加上 Aiden 双认证 → Aiden AIProxy(https://aiden-aiproxy.bytedance.net/v2)
# 默认模型 gpt-5.4（cc 内可 /model 切换档位）
unalias ccta-aiden ccad 2>/dev/null || true
ccta-aiden() {
    # 1. 检查 aiden 登录状态
    if ! command aiden auth status >/dev/null 2>&1; then
        echo "[ccta-aiden] aiden 未登录，请先运行 aiden auth login 完成 ByteCloud SSO 认证。" >&2
        return 1
    fi

    _use_claude                          # 清掉 cckm 等残留的 ANTHROPIC_* 变量，避免串味

    # 2. 启动 aiden-proxy（如果还没在跑）
    if ! command lsof -i :3457 >/dev/null 2>&1; then
        local proxy_log="$HOME/.claude/skills/claude-multi-plan/aiden-proxy.log"
        echo "[ccta-aiden] 启动 aiden-proxy ..." >&2
        nohup node "$HOME/.claude/skills/claude-multi-plan/aiden-proxy.js" >"$proxy_log" 2>&1 &
        sleep 2
        if ! command lsof -i :3457 >/dev/null 2>&1; then
            echo "[ccta-aiden] aiden-proxy 启动失败，日志：$proxy_log" >&2
            return 1
        fi
    fi

    # 3. 重启 CCR（加载最新配置）
    command ccr restart >/dev/null 2>&1

    # 4. 激活 CCR 环境变量
    eval "$(command ccr activate)"

    # 5. 安全护栏
    if [ "$ANTHROPIC_BASE_URL" != "http://127.0.0.1:3456" ]; then
        echo "[ccta-aiden] ANTHROPIC_BASE_URL 未指向本地 CCR（实际：${ANTHROPIC_BASE_URL:-空}）。已中止以防误用真 Anthropic 计费。" >&2
        return 1
    fi

    command claude --dangerously-skip-permissions "$@"
}
ccad() { ccta-aiden "$@"; }
