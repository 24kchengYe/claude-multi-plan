---
name: claude-multi-plan
description: 在任意终端（PowerShell/Git Bash/WSL）用快捷命令在 Claude 官方套餐与 Kimi 套餐之间切换运行 Claude Code，互不影响登录态；并提供字节内部链路快捷命令（ta/trae=TRAE CLI、ccta=Trae CN 网关、ccta-aiden/ccad=Aiden AIProxy）。当用户想配置多套餐切换、在不同设备复用同样配置、或问 cc/cckm/cckimi/ta/trae/ccta/ccta-aiden 之类命令时使用。
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
| `ta` | TRAE CLI | 允许所有操作（--permission-mode bypass_permissions） |
| `trae` | TRAE CLI | 普通模式（默认 Agent 模式，按需审批） |
| `ccta` | Claude Code × Trae CN 网关 | 允许所有操作；cc 跑在 Trae CN 内部模型上（经 CCR 反代） |
| `ccta-aiden` / `ccad` | Claude Code × Aiden AIProxy | 允许所有操作；cc 跑在 Aiden 内部模型上（经 CCR + aiden-proxy 双桥） |

> `ta` / `trae` 是字节内部 **TRAE CLI**（`traecli`/`traex`，基于 codex 二开）的启动快捷命令，仅 mac/linux。
> 前置：已 `curl ... install_all_platforms.sh | sh` 装好并 `traecli` 登录。
> `ta` 用官方 `bypass_permissions` 预设（可编辑工作区外文件 + 联网 + 不审批），而非文档不推荐的 `-y`（完全关沙箱）。

---

## Claude Code 跑内部模型的两种方式

字节内部有两条不同的 Claude Code 模型接入链路，**互不影响**，按需选择：

| 维度 | `ccta`（Trae CN 网关） | `ccta-aiden`（Aiden AIProxy） |
|------|------------------------|-------------------------------|
| **接入网关** | `lcd.bytedance.net/litellm_trae` | `aiden-aiproxy.bytedance.net/v2` |
| **认证方式** | Trae JWT（`~/.trae-cn/trae-jwt-token`） | ByteCloud JWT（`aiden auth get-bytecloud-jwt-token`） |
| **前置条件** | `traecli` 已登录 | `aiden auth login` 已完成 |
| **协议转换** | CCR 单桥（Anthropic → OpenAI） | CCR + aiden-proxy 双桥（Anthropic → OpenAI + 双 Header 注入） |
| **当前状态** | ⚠️ 网关不稳定，常返回空泛回复 | ✅ 已验证可用 |
| **推荐度** | 备用/观望 | **首选** |

> ⚠️ 两条链路**不能同时用**，因为都占用 `127.0.0.1:3456`（CCR）。切换前需换 `~/.claude-code-router/config.json` 和 `custom-router.js`。

### `ccta-aiden`：Claude Code × Aiden AIProxy（推荐）

想用 **Claude Code 这个壳**（TUI / skills / MCP / slash command），但模型走 **Aiden AIProxy**（字节内部统一大模型网关，PTU 资源，无需 Anthropic key）。

- **难点**：Aiden 需要 **双 Header 认证**：
  - `Authorization: Bearer sk_matthew`（固定值）
  - `X-Aiden-Client-JWT: <动态 JWT>`（24h 过期，由 `aiden auth get-bytecloud-jwt-token` 获取）
  
  CCR 只支持单 `api_key`，无法直接对接 Aiden。所以额外加了 **aiden-proxy** 本地代理。
- **桥**：两层桥接
  1. **CCR**（`127.0.0.1:3456`）：把 Claude Code 的 Anthropic `/v1/messages` 协议转成 OpenAI `/v1/chat/completions` 协议
  2. **aiden-proxy**（`127.0.0.1:3457`）：接收 CCR 的 OpenAI 请求，注入 Aiden 双 Header，转发到 `https://aiden-aiproxy.bytedance.net/v2`
- **`ccta-aiden` 做的事**：检查 `aiden` 登录态 → 启动 `aiden-proxy`（如未运行）→ `ccr restart` → `eval "$(ccr activate)"` → `claude --dangerously-skip-permissions`。带安全护栏：若 `ANTHROPIC_BASE_URL` 没指向 CCR 就中止。
  - ⚠️ **不要用 `ccr code` 启动**：v2 的 `ccr code` 不会把 `ANTHROPIC_BASE_URL` 注入到 claude 子进程，结果 cc 会拿现有 key 直连 `api.anthropic.com`（真计费）。必须 `eval "$(ccr activate)"` 后再起 `claude`。
  - 验证是否真走内部：`config.json` 设 `"LOG": true`，跑一次后 `grep aiden-aiproxy ~/.claude-code-router/logs/*.log` 应有命中、`grep api.anthropic` 应为 0。

#### Aiden 模型档位映射（custom-router）

cc 的 `/model` 菜单只有 Opus/Sonnet/Haiku，**它显示什么不代表真实后端**。用 CCR 的 `CUSTOM_ROUTER_PATH`（`~/.claude-code-router/custom-router.js`）按 cc 发来的模型名把三档映射到 Aiden 模型：

| cc 选 | 实际后端（Aiden） | 说明 |
|------|----------------|------|
| Opus | `deepseek-v4-pro` | 1M 上下文，opus 档位，PTU |
| Sonnet（默认） | `gpt-5.4` | Claude Code 默认推荐，PTU，响应快 |
| Haiku | `gpt-5.5-paygo` | 按量付费，资源可能不足 |

- **怎么知道当前用的哪个**：发请求的**响应里 `model` 字段**就是真实后端（如 `"model":"ptu_885"` 对应 gpt-5.4）；或 `"LOG": true` 后看日志的出站 `model`。
- **怎么切**：直接在 cc 里用 `/model` 选 Opus/Sonnet/Haiku，即对应 deepseek-v4-pro/gpt-5.4/gpt-5.5-paygo。想用其它模型（glm-5.1 等）：`/model trae-cn,glm-5.1`，或改 `custom-router.js` / `Router.default` 后 `ccr restart`。
- cc 的后台小任务（标题生成等）默认走 haiku → 自动落到最便宜的 `gpt-5.5-paygo`。

前置：
1. 装 CCR：`npm install -g @musistudio/claude-code-router`（已装在 `~/.local/bin/node/bin/ccr`）。
2. 配置：复制本仓库的 `claude-code-router.config.aiden.json` → `~/.claude-code-router/config.json`，`claude-code-router.custom-router.aiden.js` → `~/.claude-code-router/custom-router.js`。
3. 装 `aiden` CLI 并登录：`aiden auth login`（会打开浏览器完成 ByteCloud SSO）。

> JWT 约 24h 过期，`ccta-aiden` 启动时代理会自动刷新；若 cc 里报 401，重新跑一次 `ccta-aiden` 即可。
> aiden-proxy 进程在后台常驻，占用资源极少；若端口 3457 被占，先 `kill $(lsof -t -i:3457)` 再重启。

---

### `ccta`：Claude Code × Trae CN 网关（备用）

想用 **Claude Code 这个壳**，但模型走 **TRAE CN 内部网关**（`openrouter-2o` 等，免费、无需 Anthropic key）。

- **难点**：cc 说 Anthropic 协议（`/v1/messages`），而 Trae CN 网关（`lcd.bytedance.net/litellm_trae`）只开了 OpenAI 协议（`/v1/chat/completions`）。所以**纯 ccswitch 换环境变量不行**，必须有本地协议桥。
- **桥**：[claude-code-router](https://github.com/musistudio/claude-code-router)（CCR）。它在本地 `127.0.0.1:3456` 暴露 Anthropic 端点，把 `/v1/messages` 翻译成 OpenAI `/v1/chat/completions` 转发给 Trae CN 网关，并注入 trae JWT。
- **`ccta` 做的事**：读 `~/.trae-cn/trae-jwt-token` → `export TRAE_CN_JWT` → `ccr restart`（用最新 JWT）→ `eval "$(ccr activate)"` → `claude --dangerously-skip-permissions`。带安全护栏。

#### Trae CN 模型档位映射（custom-router）

| cc 选 | 实际后端（Trae CN） | 说明 |
|------|------------------|------|
| Opus（默认） | `openrouter-2o` | |
| Sonnet | `openrouter-1o` | |
| Haiku | `openrouter-1` | |

> ⚠️ **当前状态**：`litellm_trae` 网关不稳定，所有模型常返回空泛回复（如 "Understood. How can I help you?"）。建议优先用 `ccta-aiden`。

前置：
1. 装 CCR：`npm install -g @musistudio/claude-code-router`。
2. 配置：复制本仓库的 `claude-code-router.config.trae-cn.json` → `~/.claude-code-router/config.json`，`claude-code-router.custom-router.trae-cn.js` → `~/.claude-code-router/custom-router.js`。
3. `traecli` 已登录（保证 `~/.trae-cn/trae-jwt-token` 是新的）。

---

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

> 上面这套让 `cc` / `cckm` 在**任何电脑**可用（只需 Claude 账号 / Kimi key，不依赖字节）。
> `ta` / `trae` / `ccta` / `ccta-aiden` 还需额外条件，见下节。

## 换新电脑跑 `ta` / `trae` / `ccta` / `ccta-aiden`（需字节内网 + 认证 ByteDance）

这四个命令**必须满足两个前提**，否则用不了：
1. **在字节内网或挂 VPN** —— 依赖内部域名（安装源 `*.byted.org`、模型网关 `*.bytedance.net`），纯外网连不上。
2. **认证 ByteDance** —— `traecli` 登录（生成 `~/.trae-cn/trae-jwt-token`）或 `aiden auth login`（生成 ByteCloud JWT）。

| 命令 | 任何电脑 | 需字节内网 | 需认证 ByteDance |
|------|:---:|:---:|:---:|
| `cc` / `ccclaude` / `cckm` / `cckimi` | ✅ | 否 | 否 |
| `ta` / `trae` | 仅字节环境 | 是 | 是 |
| `ccta` | 仅字节环境 | 是 | 是（traecli） |
| `ccta-aiden` | 仅字节环境 | 是 | 是（aiden） |

新机器步骤（字节内网/VPN 可达时）：

```bash
# 1. 复用本仓库
git clone git@github.com:24kchengYe/claude-multi-plan.git ~/.claude/skills/claude-multi-plan
bash ~/.claude/skills/claude-multi-plan/install.sh

# 2. 装 TRAE CLI 并登录（= 认证 ByteDance，生成 ~/.trae-cn/trae-jwt-token）
curl -fsSL https://tosv-myabc.byted.org/obj/trae-common-2-asiasebd/traex/install/install_all_platforms.sh \
  | TRAEX_INSTALL_CHANNEL=alpha TRAEX_INSTALL_ASSUME_YES=1 sh
traecli            # git 身份回车确认；或 traecli login --sso

# 3. ccta 用：装 claude-code-router + 放配置
npm install -g @musistudio/claude-code-router
mkdir -p ~/.claude-code-router
cp ~/.claude/skills/claude-multi-plan/claude-code-router.config.trae-cn.json ~/.claude-code-router/config.json
cp ~/.claude/skills/claude-multi-plan/claude-code-router.custom-router.trae-cn.js ~/.claude-code-router/custom-router.js

# 4. ccta-aiden 用（推荐）：额外装 aiden CLI 并登录
npm install -g @aiden-cli/core --registry https://bnpm.byted.org
aiden auth login             # 浏览器 SSO 登录

# 5. 复制 aiden 配置（与 traecn 二选一，不能同时用）
cp ~/.claude/skills/claude-multi-plan/claude-code-router.config.aiden.json ~/.claude-code-router/config.json
cp ~/.claude/skills/claude-multi-plan/claude-code-router.custom-router.aiden.js ~/.claude-code-router/custom-router.js

# 6. 重开终端 → ta / trae / ccta / ccta-aiden 可用
```

> ⚠️ **不要手动拷贝 `~/.trae-cn/trae-jwt-token`**：它约 24h 过期、且按用户/机器签发。每台新机器重新 `traecli` 登录即可。
> 仓库里无密钥（配置示例用 `$TRAE_CN_JWT` / `sk_matthew` 插值，JWT 由运行时本地注入），可放心 clone 到任何机器。
> 纯私人电脑、连不上内网/VPN → `ta`/`trae`/`ccta`/`ccta-aiden` 都用不了，那台机器上只有 `cc`/`cckm` 能用。

## Kimi 套餐接入参数

- Base URL：`https://api.kimi.com/coding`（Kimi Code **订阅套餐**专属端点）
- Model：`kimi-k2.6`（或 `kimi-k2.5`）
- Key：在 https://www.kimi.com/code 的 Console 生成，格式 `sk-kimi-...`，鉴权走 `ANTHROPIC_AUTH_TOKEN`

> ⚠️ 注意区分两套端点：`api.kimi.com/coding` 是 **Kimi Code 订阅套餐**端点（`sk-kimi` key）；
> `api.moonshot.cn/anthropic` 是 **Moonshot 按量付费 API** 端点（platform key）。两者 key 不通用，用错会一直 401。

## 注意

- **key 绝不入库**：`claude-switch.local.*` 已被 `.gitignore` 排除。
- PowerShell 5.1 按 GBK 读文件会乱码，所以 `.ps1` 文件需保存为 **UTF-8 BOM**。
- 国内走 Kimi 端点建议在系统 `NO_PROXY` 里加 `.moonshot.cn`（直连不走代理）。
