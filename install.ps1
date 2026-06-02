# install.ps1 — 把 claude-switch 注入本机所有 PowerShell profile（PS5.1 + PS7）
# 用法（在 skill 目录下）：  powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$line = ". `"`$HOME\.claude\skills\claude-multi-plan\claude-switch.ps1`""
$marker = "claude-multi-plan\claude-switch.ps1"

# 覆盖 PS5.1 与 PS7 两套 profile 路径
$profiles = @(
    "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

foreach ($p in $profiles) {
    $dir = Split-Path $p
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not (Test-Path $p))   { New-Item -ItemType File -Force -Path $p | Out-Null }
    $content = Get-Content $p -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains($marker)) {
        Write-Host "[skip] 已存在引用: $p" -ForegroundColor DarkGray
    } else {
        Add-Content -Path $p -Value "`n# ===== Claude Code 套餐切换（cc/cccc/ccclaude/cckm/cckimi）=====`n$line"
        Write-Host "[ok]   已注入: $p" -ForegroundColor Green
    }
}

# 提醒配置 key
$local = Join-Path $here "claude-switch.local.ps1"
if (-not (Test-Path $local)) {
    Write-Host "`n[!] 还没有 claude-switch.local.ps1，请复制 .example 并填入你的 Kimi key：" -ForegroundColor Yellow
    Write-Host "    Copy-Item '$here\claude-switch.local.ps1.example' '$local'" -ForegroundColor Yellow
}
Write-Host "`n完成。重开终端或执行  . `$PROFILE  生效。" -ForegroundColor Cyan
