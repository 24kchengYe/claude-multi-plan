---
name: claude-multi-plan
description: 在任意终端（PowerShell/Git Bash/WSL）用快捷命令在 Claude 官方套餐与 Kimi 套餐之间切换运行 Claude Code，互不影响登录态。当用户想配置多套餐切换、在不同设备复用同样配置、或问 cc/cckm/cckimi 之类命令时使用。
---

# claude-multi-plan

让一台机器的任意终端都能用一组快捷命令，在**官方 Claude 套餐**和 **Kimi 套餐**之间切换运行 Claude Code。不同终端窗口可同时各用一个套餐，互不冲突，也不影响官方登录态。

## 命令

| 命令 | 套餐 | 模式 |
|------|------|------|
| `cc` / `cccc` | 官方登录 | 允许所有操作（--dangerously-skip-permissions） |
| `ccclaude` | 官方登录 | 普通确认 |
| `cckm` | Kimi 套餐 | 允许所有操作 |
| `cckimi` | Kimi 套餐 | 普通确认 |

## 原理

Claude Code 用哪套额度取决于三个环境变量：`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_MODEL`。
- 官方命令：清空这些变量 → 走本地 OAuth 登录态（`api.anthropic.com`）。
- Kimi 命令：临时设这些变量（仅当前窗口）→ 走 Kimi 端点，不触发登录、不动官方凭证。

因为变量是**窗口级**的，两个终端可同时各跑一个套餐，互不串味。

## 安装（新设备）

1. 把本 skill 目录放到 `~/.claude/skills/claude-multi-plan/`。
2. 配置 key（不会上传）：
   - bash: `cp claude-switch.local.sh.example claude-switch.local.sh` 后填入 Kimi key
   - PowerShell: `Copy-Item claude-switch.local.ps1.example claude-switch.local.ps1` 后填入 Kimi key
3. 注入终端配置：
   - bash / zsh / WSL: `bash install.sh`（自动识别 macOS→`~/.zshrc`、Linux/Git Bash→`~/.bashrc`；可用 `RC=...` 手动指定）
   - PowerShell: `powershell -ExecutionPolicy Bypass -File install.ps1`
4. 重开终端，或 `source ~/.zshrc`(Mac) / `source ~/.bashrc` / `. $PROFILE`。

支持的终端：Windows PowerShell 5.1 / PowerShell 7 / Git Bash / WSL，macOS/Linux 的 bash 与 zsh。

## Kimi 套餐接入参数

- Base URL：`https://api.kimi.com/coding`（Kimi Code **订阅套餐**专属端点）
- Model：`kimi-k2.6`（或 `kimi-k2.5`）
- Key：在 https://www.kimi.com/code 的 Console 生成，格式 `sk-kimi-...`，鉴权走 `ANTHROPIC_AUTH_TOKEN`

> ⚠️ 注意区分两套端点：`api.kimi.com/coding` 是 **Kimi Code 订阅套餐**端点（`sk-kimi-` key）；
> `api.moonshot.cn/anthropic` 是 **Moonshot 按量付费 API** 端点（platform key）。两者 key 不通用，用错会一直 401。

## 注意

- **key 绝不入库**：`claude-switch.local.*` 已被 `.gitignore` 排除。
- PowerShell 5.1 按 GBK 读文件会乱码，所以 `.ps1` 文件需保存为 **UTF-8 BOM**。
- 国内走 Kimi 端点建议在系统 `NO_PROXY` 里加 `.moonshot.cn`（直连不走代理）。
