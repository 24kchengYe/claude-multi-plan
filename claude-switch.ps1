# claude-switch.ps1 — Claude Code 多套餐切换（PowerShell 版）
# 适用 Windows PowerShell 5.1 和 PowerShell 7+
# 在你的 $PROFILE 里加一行引用它，例如：
#   . "$HOME\.claude\skills\claude-multi-plan\claude-switch.ps1"
#
# 命令：
#   cc / cccc  -> 官方登录 + 允许所有操作
#   ccclaude   -> 官方登录 + 普通
#   cckm       -> Kimi 套餐 + 允许所有操作
#   cckimi     -> Kimi 套餐 + 普通

# ---- Kimi 套餐配置 ----
# key 不写在这里。放到同目录的 claude-switch.local.ps1（该文件不上传 GitHub）。
$KimiBaseUrl = "https://api.kimi.com/coding"
$KimiModel   = "kimi-k2.6"
$KimiKey     = ""   # 由 claude-switch.local.ps1 覆盖

# 读取本地私密配置（含 key），存在才加载
$__localCfg = Join-Path $PSScriptRoot "claude-switch.local.ps1"
if (Test-Path $__localCfg) { . $__localCfg }

# 切回官方登录态：清掉所有 Kimi 环境变量
function _UseClaude {
    Remove-Item Env:ANTHROPIC_BASE_URL             -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN           -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_MODEL                -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL   -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
}

# 切到 Kimi 套餐（仅当前窗口）
function _UseKimi {
    if ([string]::IsNullOrEmpty($KimiKey)) {
        Write-Host "[claude-switch] 未配置 Kimi key。请在 claude-switch.local.ps1 里设置 `$KimiKey。" -ForegroundColor Yellow
        return $false
    }
    $env:ANTHROPIC_BASE_URL             = $KimiBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN           = $KimiKey
    $env:ANTHROPIC_MODEL                = $KimiModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL   = $KimiModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $KimiModel
    return $true
}

# 官方 + 允许所有操作
function cc   { _UseClaude; claude --dangerously-skip-permissions @args }
function cccc { _UseClaude; claude --dangerously-skip-permissions @args }
# 官方 + 普通
function ccclaude { _UseClaude; claude @args }
# Kimi 套餐 + 允许所有操作
function cckm { if (_UseKimi) { claude --dangerously-skip-permissions @args } }
# Kimi 套餐 + 普通
function cckimi { if (_UseKimi) { claude @args } }
