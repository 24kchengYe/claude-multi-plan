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
#   ccds       -> DeepSeek 套餐 + 允许所有操作
#   ccdeepseek -> DeepSeek 套餐 + 普通

# ---- Kimi 套餐配置 ----
# key 不写在这里。放到同目录的 claude-switch.local.ps1（该文件不上传 GitHub）。
$KimiBaseUrl       = "https://api.kimi.com/coding/"
$KimiModel         = "k3[1m]"
$KimiContextTokens = "1048576"
$KimiKey           = ""   # 由 claude-switch.local.ps1 覆盖

# ---- DeepSeek 套餐配置 ----
# DeepSeek 官方 Anthropic 兼容端点（无需协议转换，直连即可）
$DeepSeekBaseUrl   = "https://api.deepseek.com/anthropic"
$DeepSeekModel     = "deepseek-v4-pro[1m]"   # 默认主力：V4 Pro（思考型旗舰）；[1m] 后缀开启 1M 上下文档位（不带后缀端点按 200k 服务）
$DeepSeekFastModel = "deepseek-chat"     # 小任务/后台：V4 Flash（快、便宜）
$DeepSeekKey       = ""   # 由 claude-switch.local.ps1 覆盖

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
    Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL     -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_SUBAGENT_MODEL     -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_AUTO_COMPACT_WINDOW -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_CODE_MAX_CONTEXT_TOKENS -ErrorAction SilentlyContinue
}

# 切到 Kimi 套餐（仅当前窗口）
# Key 解析顺序：claude-switch.local.ps1 里的 $KimiKey 显式覆盖 > ai-api-gateway 解锁文件
# （默认 D:\server-ops\secrets\ai-gateway-secrets.env，可用 $env:AI_GATEWAY_SECRETS_PATH 覆盖）里的 KIMI_CODE_API_KEY
function _UseKimi {
    $kmKey = $KimiKey
    if ([string]::IsNullOrEmpty($kmKey)) {
        $store = $env:AI_GATEWAY_SECRETS_PATH
        if ([string]::IsNullOrEmpty($store)) { $store = 'D:\server-ops\secrets\ai-gateway-secrets.env' }
        if (Test-Path -LiteralPath $store) {
            $m = Get-Content -LiteralPath $store | Where-Object { $_ -match '^KIMI_CODE_API_KEY=(.+)$' } | Select-Object -Last 1
            if ($m) { $kmKey = ($m -split '=',2)[1].Trim() }
        }
    }
    if ([string]::IsNullOrEmpty($kmKey)) {
        Write-Host "[claude-switch] 未配置 Kimi key。请解锁 ai-api-gateway（ai-gateway-secrets.env 含 KIMI_CODE_API_KEY）或在 claude-switch.local.ps1 里设置 `$KimiKey。" -ForegroundColor Yellow
        return $false
    }
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    $env:ANTHROPIC_BASE_URL               = $KimiBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN             = $kmKey
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

# 切到 DeepSeek 套餐（仅当前窗口）
# DeepSeek 端点原生兼容 Anthropic 协议，无需 CCR 反代；先清场再设变量，避免与 cckm 等残留串味
# Key 解析顺序：claude-switch.local.ps1 里的 $DeepSeekKey 显式覆盖 > ai-api-gateway 解锁文件
# （默认 D:\server-ops\secrets\ai-gateway-secrets.env，可用 $env:AI_GATEWAY_SECRETS_PATH 覆盖）里的 DEEPSEEK_API_KEY
function _UseDeepSeek {
    $dsKey = $DeepSeekKey
    if ([string]::IsNullOrEmpty($dsKey)) {
        $store = $env:AI_GATEWAY_SECRETS_PATH
        if ([string]::IsNullOrEmpty($store)) { $store = 'D:\server-ops\secrets\ai-gateway-secrets.env' }
        if (Test-Path -LiteralPath $store) {
            $m = Get-Content -LiteralPath $store | Where-Object { $_ -match '^DEEPSEEK_API_KEY=(.+)$' } | Select-Object -Last 1
            if ($m) { $dsKey = ($m -split '=',2)[1].Trim() }
        }
    }
    if ([string]::IsNullOrEmpty($dsKey)) {
        Write-Host "[claude-switch] 未配置 DeepSeek key。请解锁 ai-api-gateway（ai-gateway-secrets.env 含 DEEPSEEK_API_KEY）或在 claude-switch.local.ps1 里设置 `$DeepSeekKey。" -ForegroundColor Yellow
        return $false
    }
    _UseClaude
    $env:ANTHROPIC_BASE_URL               = $DeepSeekBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN             = $dsKey
    $env:ANTHROPIC_MODEL                  = $DeepSeekModel
    $env:ANTHROPIC_SMALL_FAST_MODEL       = $DeepSeekFastModel   # 后台小任务走 Flash，避免 404 且省钱
    $env:ANTHROPIC_DEFAULT_FABLE_MODEL    = $DeepSeekModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL     = $DeepSeekModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL   = $DeepSeekModel
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL    = $DeepSeekFastModel
    $env:CLAUDE_CODE_SUBAGENT_MODEL       = $DeepSeekModel
    return $true
}

# Codex CLI：默认 codex 走全权限模式；需要正常审批/沙箱时用 codexsafe。
function _CodexBin {
    $cmds = @(Get-Command codex -CommandType Application -ErrorAction Stop)
    $cmd = $cmds | Where-Object { $_.Source -like '*.cmd' -or $_.Source -like '*.exe' } | Select-Object -First 1
    if (-not $cmd) { $cmd = $cmds | Select-Object -First 1 }
    return $cmd.Source
}
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
# DeepSeek 套餐 + 允许所有操作
function ccds { if (_UseDeepSeek) { claude --dangerously-skip-permissions @args } }
# DeepSeek 套餐 + 普通
function ccdeepseek { if (_UseDeepSeek) { claude @args } }

# ---- cd* = Codex CLI × 后端矩阵（全权限）----
# cdx  = Codex × 当前 cc-switch 槽位
# cdds = Codex × DeepSeek（deepseek-v4-pro，self key；隔离 CODEX_HOME=~/.codex-deepseek，不动 cc-switch 登录态）
# cdkm = Codex × Kimi（k3，KIMI_CODE_API_KEY；隔离 CODEX_HOME=~/.codex-kimi）
# key 均从 ai-api-gateway 解锁文件读取

function _ReadStoreField {
    param([string]$Field)
    $store = $env:AI_GATEWAY_SECRETS_PATH
    if ([string]::IsNullOrEmpty($store)) { $store = 'D:\server-ops\secrets\ai-gateway-secrets.env' }
    if (Test-Path -LiteralPath $store) {
        $m = Get-Content -LiteralPath $store | Where-Object { $_ -match ('^' + [regex]::Escape($Field) + '=(.+)$') } | Select-Object -Last 1
        if ($m) { return ($m -split '=',2)[1].Trim() }
    }
    return $null
}

function _CodexBackendHome {
    param([string]$Name, [string]$Model, [string]$BaseUrl, [string]$EnvKey, [string]$Provider, [string]$ExtraCfg = '', [string]$WebMode = '', [int]$ContextWindow = 262144)
    $codexHome = Join-Path $env:USERPROFILE ('.codex-' + $Name)
    New-Item -ItemType Directory -Force $codexHome | Out-Null
    # 从主 CODEX_HOME 播种沙箱注册状态，跳过首次运行的 Windows 沙箱设置提示。
    # cd* 恒以 --dangerously-bypass-approvals-and-sandbox 运行、沙箱不实际使用，复制只为满足首次运行检查。
    foreach ($item in @('.sandbox', '.sandbox-bin', '.sandbox-secrets', 'cap_sid', '.sandbox_migration')) {
        $src = Join-Path $env:USERPROFILE ('.codex\' + $item)
        if ((Test-Path $src) -and -not (Test-Path (Join-Path $codexHome $item))) {
            Copy-Item $src (Join-Path $codexHome $item) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $webLine = ''
    if ($WebMode) { $webLine = 'web_search = "' + $WebMode + '"' }
    $compactLimit = [int]($ContextWindow * 0.8)
    $cfg = @"
model = "$Model"
model_provider = "$Provider"

[model_providers.$Provider]
name = "$Provider"
base_url = "$BaseUrl"
env_key = "$EnvKey"
wire_api = "responses"
$webLine
$ExtraCfg
model_context_window = $ContextWindow
model_auto_compact_token_limit = $compactLimit

[windows]
sandbox = "elevated"
"@
    Set-Content -LiteralPath (Join-Path $codexHome 'config.toml') -Value $cfg -Encoding ascii
    return $codexHome
}

function _RunCodexBackend {
    param([string]$HomeSuffix, [string]$Model, [string]$BaseUrl, [string]$EnvKey, [string]$Provider, [string]$StoreField, [string]$ExtraCfg = '', [string]$WebMode = '', [int]$ContextWindow = 262144)
    $key = _ReadStoreField $StoreField
    if (-not $key) {
        Write-Host ("[claude-switch] 未找到 " + $StoreField + "（请先解锁 ai-api-gateway）") -ForegroundColor Yellow
        return
    }
    $codexHome = _CodexBackendHome $HomeSuffix $Model $BaseUrl $EnvKey $Provider $ExtraCfg $WebMode $ContextWindow
    $prevHome = $env:CODEX_HOME
    $prevKey = [Environment]::GetEnvironmentVariable($EnvKey, 'Process')
    try {
        $env:CODEX_HOME = $codexHome
        [Environment]::SetEnvironmentVariable($EnvKey, $key, 'Process')
        $argList = @($args)
        if ($argList.Count -gt 0 -and $argList[0] -eq 'exec') {
            # exec 分支：-c 强制覆盖，防止当前目录的项目级 .codex/config.toml 盖掉后端配置
            $rest = @()
            if ($argList.Count -gt 1) { $rest = $argList[1..($argList.Count - 1)] }
            $extraC = @()
            if ($WebMode) { $extraC = @('-c', ('web_search=' + $WebMode)) }
            & (_CodexBin) exec --dangerously-bypass-approvals-and-sandbox -c ("model=" + $Model) -c ("model_provider=" + $Provider) @extraC @rest
        } else {
            $extraC = @()
            if ($WebMode) { $extraC = @('-c', ('web_search=' + $WebMode)) }
            & (_CodexBin) --dangerously-bypass-approvals-and-sandbox -c ("model=" + $Model) -c ("model_provider=" + $Provider) @extraC @args
        }
    } finally {
        if ($null -eq $prevHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $prevHome }
        if ($null -eq $prevKey) { Remove-Item ("Env:" + $EnvKey) -ErrorAction SilentlyContinue } else { [Environment]::SetEnvironmentVariable($EnvKey, $prevKey, 'Process') }
    }
}

function cdx  { codex @args }
function cdds { _RunCodexBackend 'deepseek' 'deepseek-v4-pro' 'https://api.deepseek.com/v1' 'DEEPSEEK_API_KEY' 'deepseek' 'DEEPSEEK_API_KEY' '' '' 1048576 }
function cdkm { _RunCodexBackend 'kimi' 'k3' 'https://api.kimi.com/coding/v1' 'KIMI_API_KEY' 'kimi' 'KIMI_CODE_API_KEY' '' 'disabled' 262144 }
