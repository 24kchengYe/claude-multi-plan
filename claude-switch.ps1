# claude-switch.ps1 — Claude Code 多套餐切换（PowerShell 版）
# 适用 Windows PowerShell 5.1 和 PowerShell 7+
# 在你的 $PROFILE 里加一行引用它，例如：
#   . "$HOME\.claude\skills\claude-multi-plan\claude-switch.ps1"
#
# 命令：
#   codex      -> Codex CLI + 允许所有操作
#   codexsafe  -> Codex CLI + 普通确认
#   cc / cccc  -> 官方登录 + 允许所有操作
#   ccclaude   -> 官方登录 + 普通
#   cckm       -> Kimi 套餐 + 允许所有操作
#   cckimi     -> Kimi 套餐 + 普通

# ---- Kimi 套餐配置 ----
# key 不写在这里。放到同目录的 claude-switch.local.ps1（该文件不上传 GitHub）。
$KimiBaseUrl       = "https://api.kimi.com/coding/"
$KimiModel         = "k3[1m]"
$KimiContextTokens = "1048576"
$KimiKey           = ""   # 由 claude-switch.local.ps1 覆盖

# 读取本地私密配置（含 key），存在才加载
$__localCfg = Join-Path $PSScriptRoot "claude-switch.local.ps1"
if (Test-Path $__localCfg) { . $__localCfg }

# 切回官方登录态：清掉所有 Kimi 环境变量
function _UseClaude {
    Remove-Item Env:ANTHROPIC_BASE_URL             -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN           -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY              -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_MODEL                -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_EFFORT_LEVEL       -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_FABLE_MODEL  -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL   -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL  -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_SUBAGENT_MODEL     -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_AUTO_COMPACT_WINDOW -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_MAX_CONTEXT_TOKENS -ErrorAction SilentlyContinue
}

# 切到 Kimi 套餐（仅当前窗口）
function _UseKimi {
    if ([string]::IsNullOrEmpty($KimiKey)) {
        Write-Host "[claude-switch] 未配置 Kimi key。请在 claude-switch.local.ps1 里设置 `$KimiKey。" -ForegroundColor Yellow
        return $false
    }
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    $env:ANTHROPIC_BASE_URL               = $KimiBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN             = $KimiKey
    $env:ANTHROPIC_MODEL                  = $KimiModel
    $env:CLAUDE_CODE_EFFORT_LEVEL         = "high"
    $env:ANTHROPIC_DEFAULT_FABLE_MODEL    = $KimiModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL     = $KimiModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL   = $KimiModel
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL    = $KimiModel
    $env:CLAUDE_CODE_SUBAGENT_MODEL       = $KimiModel
    $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $KimiContextTokens
    $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS   = $KimiContextTokens
    return $true
}

# Codex CLI：默认 codex 走全权限模式；需要正常审批/沙箱时用 codexsafe。
function _CodexBin { (Get-Command codex -CommandType Application -ErrorAction Stop).Source }
function codex { & (_CodexBin) --dangerously-bypass-approvals-and-sandbox @args }
function codexsafe { & (_CodexBin) @args }

# 官方 + 允许所有操作
function cc   { _UseClaude; claude --dangerously-skip-permissions @args }
function cccc { _UseClaude; claude --dangerously-skip-permissions @args }
# 官方 + 普通
function ccclaude { _UseClaude; claude @args }
# Kimi 套餐 + 允许所有操作
function cckm { if (_UseKimi) { claude --dangerously-skip-permissions @args } }
# Kimi 套餐 + 普通
function cckimi { if (_UseKimi) { claude @args } }
