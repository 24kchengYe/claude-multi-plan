#!/usr/bin/env bash
# claude-switch.sh — Claude Code 多套餐切换（bash 版）
# 适用 Git Bash / WSL / Linux / macOS
# 在你的 ~/.bashrc 或 ~/.zshrc 里加一行引用它，例如：
#   source "$HOME/.claude/skills/claude-multi-plan/claude-switch.sh"
#
# 命令：
#   codex      -> Codex CLI + 允许所有操作
#   codexsafe  -> Codex CLI + 普通确认
#   cc / cccc  -> 官方登录 + 允许所有操作
#   ccclaude   -> 官方登录 + 普通
#   cckm       -> Kimi 套餐 + 允许所有操作
#   cckimi     -> Kimi 套餐 + 普通
#   ccds       -> DeepSeek 套餐 + 允许所有操作
#   ccdeepseek -> DeepSeek 套餐 + 普通
#   ta         -> TRAE CLI + 允许所有操作（bypass_permissions）
#   trae       -> TRAE CLI 普通模式

# ---- Kimi 套餐配置 ----
# key 不写在这里。放到同目录的 claude-switch.local.sh（该文件不上传 GitHub）。
KIMI_BASE_URL="https://api.kimi.com/coding/"
KIMI_MODEL="k3[1m]"
KIMI_CONTEXT_TOKENS="1048576"
KIMI_KEY=""   # 由 claude-switch.local.sh 覆盖

# ---- DeepSeek 套餐配置 ----
# DeepSeek 官方 Anthropic 兼容端点（无需协议转换，直连即可）
DEEPSEEK_BASE_URL="https://api.deepseek.com/anthropic"
DEEPSEEK_MODEL="deepseek-v4-pro"   # 默认主力：V4 Pro（思考型旗舰）
DEEPSEEK_FAST_MODEL="deepseek-chat"   # 小任务/后台：V4 Flash（快、便宜）
DEEPSEEK_KEY=""   # 由 claude-switch.local.sh 覆盖

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
          ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
          ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
          ANTHROPIC_SMALL_FAST_MODEL \
          CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_AUTO_COMPACT_WINDOW \
          CLAUDE_CODE_MAX_CONTEXT_TOKENS CLAUDE_CODE_EFFORT_LEVEL ANTHROPIC_API_KEY
}

# 切到 Kimi 套餐（仅当前 shell）
# Key 解析顺序：claude-switch.local.sh 里的 KIMI_KEY 显式覆盖 > ai-api-gateway 解锁文件
# （默认 ~/.config/ai-gateway/secrets.env，可用 AI_GATEWAY_SECRETS_PATH 覆盖）里的 KIMI_CODE_API_KEY
_use_kimi() {
    local km_key="$KIMI_KEY"
    if [ -z "$km_key" ]; then
        local store="${AI_GATEWAY_SECRETS_PATH:-$HOME/.config/ai-gateway/secrets.env}"
        if [ -f "$store" ]; then
            km_key="$(grep -E '^KIMI_CODE_API_KEY=.+$' "$store" | tail -n 1 | cut -d= -f2-)"
        fi
    fi
    if [ -z "$km_key" ]; then
        echo "[claude-switch] 未配置 Kimi key。请解锁 ai-api-gateway（secrets.env 含 KIMI_CODE_API_KEY）或在 claude-switch.local.sh 里设置 KIMI_KEY。" >&2
        return 1
    fi
    # 先清掉旧的 API key，避免和 AUTH_TOKEN 冲突
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$KIMI_BASE_URL"
    export ANTHROPIC_AUTH_TOKEN="$km_key"
    export ANTHROPIC_MODEL="$KIMI_MODEL"
    export CLAUDE_CODE_EFFORT_LEVEL="high"
    export ANTHROPIC_DEFAULT_FABLE_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$KIMI_MODEL"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$KIMI_MODEL"
    export CLAUDE_CODE_SUBAGENT_MODEL="$KIMI_MODEL"
    export CLAUDE_CODE_AUTO_COMPACT_WINDOW="$KIMI_CONTEXT_TOKENS"
    export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$KIMI_CONTEXT_TOKENS"
}

# 切到 DeepSeek 套餐（仅当前 shell）
# DeepSeek 端点原生兼容 Anthropic 协议，无需 CCR 反代；先清场再设变量，避免与 cckm 等残留串味
# Key 解析顺序：claude-switch.local.sh 里的 DEEPSEEK_KEY 显式覆盖 > ai-api-gateway 解锁文件
# （默认 ~/.config/ai-gateway/secrets.env，可用 AI_GATEWAY_SECRETS_PATH 覆盖）里的 DEEPSEEK_API_KEY
_use_deepseek() {
    local ds_key="$DEEPSEEK_KEY"
    if [ -z "$ds_key" ]; then
        local store="${AI_GATEWAY_SECRETS_PATH:-$HOME/.config/ai-gateway/secrets.env}"
        if [ -f "$store" ]; then
            ds_key="$(grep -E '^DEEPSEEK_API_KEY=.+$' "$store" | tail -n 1 | cut -d= -f2-)"
        fi
    fi
    if [ -z "$ds_key" ]; then
        echo "[claude-switch] 未配置 DeepSeek key。请解锁 ai-api-gateway（secrets.env 含 DEEPSEEK_API_KEY）或在 claude-switch.local.sh 里设置 DEEPSEEK_KEY。" >&2
        return 1
    fi
    _use_claude
    export ANTHROPIC_BASE_URL="$DEEPSEEK_BASE_URL"
    export ANTHROPIC_AUTH_TOKEN="$ds_key"
    export ANTHROPIC_MODEL="$DEEPSEEK_MODEL"
    export ANTHROPIC_SMALL_FAST_MODEL="$DEEPSEEK_FAST_MODEL"   # 后台小任务走 Flash，避免 404 且省钱
    export ANTHROPIC_DEFAULT_FABLE_MODEL="$DEEPSEEK_MODEL"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$DEEPSEEK_MODEL"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$DEEPSEEK_MODEL"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$DEEPSEEK_FAST_MODEL"
    export CLAUDE_CODE_SUBAGENT_MODEL="$DEEPSEEK_MODEL"
}

# 先解除可能存在的同名 alias，避免函数定义语法冲突
unalias cc cccc ccclaude cckm cckimi ccds ccdeepseek 2>/dev/null || true

# 官方 + 允许所有操作
cc()   { _use_claude; claude --dangerously-skip-permissions "$@"; }
cccc() { _use_claude; claude --dangerously-skip-permissions "$@"; }
# 官方 + 普通
ccclaude() { _use_claude; claude "$@"; }
# Kimi 套餐 + 允许所有操作
cckm() { _use_kimi && claude --dangerously-skip-permissions "$@"; }
# Kimi 套餐 + 普通
cckimi() { _use_kimi && claude "$@"; }
# DeepSeek 套餐 + 允许所有操作
ccds() { _use_deepseek && claude --dangerously-skip-permissions "$@"; }
# DeepSeek 套餐 + 普通
ccdeepseek() { _use_deepseek && claude "$@"; }

# ---- cd* = Codex CLI × 后端矩阵（全权限）----
# cdx  = Codex × 当前 cc-switch 槽位
# cdds = Codex × DeepSeek（deepseek-v4-pro，self key；隔离 CODEX_HOME=~/.codex-deepseek，不动 cc-switch 登录态）
# cdkm = Codex × Kimi（k3，KIMI_CODE_API_KEY；隔离 CODEX_HOME=~/.codex-kimi）
# key 均从 ai-api-gateway 解锁文件读取
unalias cdx cdkm cdds 2>/dev/null || true
_cms_store() { echo "${AI_GATEWAY_SECRETS_PATH:-$HOME/.config/ai-gateway/secrets.env}"; }
_cms_field() {
    grep -E "^$1=.+$" "$(_cms_store)" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '\r'
}
_codex_backend() {
    # $1=home suffix, $2=model, $3=base_url, $4=env_key(config), $5=provider, $6=store field, $7=env var name, $8=extra TOML, $9=web_search mode, $10=context window
    local suffix="$1" model="$2" base_url="$3" env_key_cfg="$4" provider="$5" store_field="$6" env_name="$7" extra_cfg="$8" web_mode="$9" ctx="${10:-262144}"
    shift 10
    local key home web_line compact_limit
    key="$(_cms_field "$store_field")"
    if [ -z "$key" ]; then
        echo "[claude-switch] 未找到 $store_field（请先解锁 ai-api-gateway）" >&2
        return 1
    fi
    [ -n "$web_mode" ] && web_line="web_search = \"$web_mode\"" || web_line=""
    compact_limit=$((ctx * 80 / 100))
    home="$HOME/.codex-$suffix"
    mkdir -p "$home"
    # 从主 CODEX_HOME 播种沙箱注册状态，跳过首次运行的 Windows 沙箱设置提示
    # （cd* 恒以 bypass 运行、沙箱不实际使用；macOS 无此提示，复制为空操作）
    for item in .sandbox .sandbox-bin .sandbox-secrets cap_sid .sandbox_migration; do
        if [ -e "$HOME/.codex/$item" ] && [ ! -e "$home/$item" ]; then
            cp -R "$HOME/.codex/$item" "$home/$item" 2>/dev/null || true
        fi
    done
    cat > "$home/config.toml" <<EOF
model = "$model"
model_provider = "$provider"

[model_providers.$provider]
name = "$provider"
base_url = "$base_url"
env_key = "$env_key_cfg"
wire_api = "responses"
$web_line
$extra_cfg
model_context_window = $ctx
model_auto_compact_token_limit = $compact_limit

[windows]
sandbox = "elevated"
EOF
    if [ "$1" = "exec" ]; then
        # exec 分支：-c 强制覆盖，防止当前目录的项目级 .codex/config.toml 盖掉后端配置
        shift
        if [ -n "$web_mode" ]; then
            env "$env_name"="$key" CODEX_HOME="$home" command codex exec --dangerously-bypass-approvals-and-sandbox -c "model=$model" -c "model_provider=$provider" -c "web_search=$web_mode" "$@"
        else
            env "$env_name"="$key" CODEX_HOME="$home" command codex exec --dangerously-bypass-approvals-and-sandbox -c "model=$model" -c "model_provider=$provider" "$@"
        fi
    else
        if [ -n "$web_mode" ]; then
            env "$env_name"="$key" CODEX_HOME="$home" command codex --dangerously-bypass-approvals-and-sandbox -c "model=$model" -c "model_provider=$provider" -c "web_search=$web_mode" "$@"
        else
            env "$env_name"="$key" CODEX_HOME="$home" command codex --dangerously-bypass-approvals-and-sandbox -c "model=$model" -c "model_provider=$provider" "$@"
        fi
    fi
}
cdx()  { codex "$@"; }
cdds() { _codex_backend deepseek 'deepseek-v4-pro' 'https://api.deepseek.com/v1' DEEPSEEK_API_KEY deepseek DEEPSEEK_API_KEY DEEPSEEK_API_KEY '' '' 1048576 "$@"; }
cdkm() { _codex_backend kimi 'k3' 'https://api.kimi.com/coding/v1' KIMI_API_KEY kimi KIMI_CODE_API_KEY KIMI_API_KEY '' 'disabled' 262144 "$@"; }

# ---- TRAE CLI 启动模式（traecli/traex，仅 mac/linux）----
# traex/traecli 装在 ~/.local/bin，ccr/node 装在 ~/.local/bin/node/bin，确保都在 PATH 上
for __d in "$HOME/.local/bin" "$HOME/.local/bin/node/bin"; do
    case ":$PATH:" in
        *":$__d:"*) ;;
        *) [ -d "$__d" ] && export PATH="$__d:$PATH" ;;
    esac
done
unset __d

# ---- Codex CLI 启动模式 ----
unalias codex codexsafe 2>/dev/null || true
# 默认 codex 走全权限模式；需要正常审批/沙箱时用 codexsafe。
codex() { command codex --dangerously-bypass-approvals-and-sandbox "$@"; }
codexsafe() { command codex "$@"; }

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

# ---- ccllm：Claude Code 跑在 ModelHub / LiteLLM 上（经 CCR 单桥）----
# Claude Code 发 Anthropic 协议 → CCR(127.0.0.1:3456) 转成 OpenAI 协议 →
# 直接对接 LiteLLM(https://lcd.bytedance.net/litellm/v1/chat/completions)
# 默认模型 gpt-5.4-2026-03-05（cc 内可 /model 切换档位）
unalias ccllm 2>/dev/null || true
ccllm() {
    _use_claude                          # 清掉 cckm 等残留的 ANTHROPIC_* 变量，避免串味

    # 重启 CCR（加载最新 LiteLLM 配置）
    command ccr restart >/dev/null 2>&1

    # 激活 CCR 环境变量
    eval "$(command ccr activate)"

    # 安全护栏
    if [ "$ANTHROPIC_BASE_URL" != "http://127.0.0.1:3456" ]; then
        echo "[ccllm] ANTHROPIC_BASE_URL 未指向本地 CCR（实际：${ANTHROPIC_BASE_URL:-空}）。已中止以防误用真 Anthropic 计费。" >&2
        return 1
    fi

    command claude --dangerously-skip-permissions "$@"
}

# ---- ccad：Claude Code 跑在 Aiden AIProxy 上（经本地 CCR + aiden-proxy 双桥）----
# Claude Code 发 Anthropic 协议 → CCR(127.0.0.1:3456) 转成 OpenAI 协议 →
# aiden-proxy(127.0.0.1:3457) 加上 Aiden 双认证 → Aiden AIProxy(https://aiden-aiproxy.bytedance.net/v2)
# 默认模型 gpt-5.4（cc 内可 /model 切换档位）
unalias ccad 2>/dev/null || true
ccad() {
    # 1. 检查 aiden 登录状态
    if ! command aiden auth status >/dev/null 2>&1; then
        echo "[ccad] aiden 未登录，请先运行 aiden auth login 完成 ByteCloud SSO 认证。" >&2
        return 1
    fi

    _use_claude                          # 清掉 cckm 等残留的 ANTHROPIC_* 变量，避免串味

    # 2. 启动 aiden-proxy（如果还没在跑）
    if ! command lsof -i :3457 >/dev/null 2>&1; then
        local proxy_log="$HOME/.claude/skills/claude-multi-plan/aiden-proxy.log"
        echo "[ccad] 启动 aiden-proxy ..." >&2
        nohup node "$HOME/.claude/skills/claude-multi-plan/aiden-proxy.js" >"$proxy_log" 2>&1 &
        sleep 2
        if ! command lsof -i :3457 >/dev/null 2>&1; then
            echo "[ccad] aiden-proxy 启动失败，日志：$proxy_log" >&2
            return 1
        fi
    fi

    # 3. 重启 CCR（加载最新配置）
    command ccr restart >/dev/null 2>&1

    # 4. 激活 CCR 环境变量
    eval "$(command ccr activate)"

    # 5. 安全护栏
    if [ "$ANTHROPIC_BASE_URL" != "http://127.0.0.1:3456" ]; then
        echo "[ccad] ANTHROPIC_BASE_URL 未指向本地 CCR（实际：${ANTHROPIC_BASE_URL:-空}）。已中止以防误用真 Anthropic 计费。" >&2
        return 1
    fi

    command claude --dangerously-skip-permissions "$@"
}
