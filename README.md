# Sub2API + New API + Codex Local Gateway

[中文](#中文说明) | [English](#english)

## 中文说明

这是一个可复用的一键部署项目，用于部署个人自用的本地/服务器 AI 网关：

```text
ChatGPT / Claude 订阅账号 -> Sub2API -> New API -> Codex App / Codex CLI
DeepSeek 官方 API Key     -> New API -> Codex App / Codex CLI
```

Codex 通过 New API 调用，并使用 OpenAI Responses API：

```text
POST http://127.0.0.1:3000/v1/responses
```

> 说明：仓库目录是部署模板；真正运行的服务默认部署在 `$HOME/ai-gateway`，不在本仓库目录里。

### 默认部署内容

| 项目 | 默认值 |
|---|---|
| 网关运行目录 | `$HOME/ai-gateway` |
| Sub2API | `http://127.0.0.1:8080` |
| New API | `http://127.0.0.1:3000` |
| Codex 配置 | `$HOME/.codex/config.toml` |
| Codex Skill | `$HOME/.codex/skills/sub2api-newapi-codex/SKILL.md` |
| 本机私有凭据 | `$HOME/ai-gateway/LOCAL_CREDENTIALS.md` |

`LOCAL_CREDENTIALS.md` 只在部署机器上生成，权限为 `600`，会被 `.gitignore` 排除。它用于保存 Sub2API 初始管理员账号和密码。不要上传或分享这个文件。

### 环境要求

- Docker Engine 或 Docker Desktop
- Docker Compose plugin
- `bash`
- `curl`
- `openssl`
- 可选：`python3`，用于更稳妥地更新 Codex 配置

如果使用 Colima：

```bash
colima start
```

### 一键部署

```bash
git clone https://github.com/Shuo-O/sub2api-newapi-codex-gateway.git
cd sub2api-newapi-codex-gateway
./scripts/install.sh
```

部署完成后打开：

```text
Sub2API: http://127.0.0.1:8080
New API: http://127.0.0.1:3000
```

查看 Sub2API 管理员账号和密码：

```bash
cat "$HOME/ai-gateway/LOCAL_CREDENTIALS.md"
```

### 自定义部署

```bash
AI_GATEWAY_HOME="$HOME/ai-gateway" \
AI_GATEWAY_BIND_HOST="127.0.0.1" \
SUB2API_PORT="8080" \
NEW_API_PORT="3000" \
CODEX_HOME="$HOME/.codex" \
CODEX_MODEL="gpt-5-codex" \
./scripts/install.sh
```

| 变量 | 默认值 | 说明 |
|---|---|---|
| `AI_GATEWAY_HOME` | `$HOME/ai-gateway` | 运行目录 |
| `AI_GATEWAY_BIND_HOST` | `127.0.0.1` | Docker 端口绑定地址 |
| `SUB2API_PORT` | `8080` | Sub2API 宿主机端口 |
| `NEW_API_PORT` | `3000` | New API 宿主机端口 |
| `CODEX_HOME` | `$HOME/.codex` | Codex 配置目录 |
| `CODEX_MODEL` | `gpt-5-codex` | Codex 请求的模型名 |
| `INSTALL_CODEX_CONFIG` | `1` | 设为 `0` 可跳过 Codex 配置更新 |
| `SUB2API_ADMIN_EMAIL` | `admin@sub2api.local` | 新部署的 Sub2API 初始管理员账号 |
| `SUB2API_ADMIN_PASSWORD` | 自动生成 | 新部署的 Sub2API 初始管理员密码 |

服务器部署时建议仍绑定 `127.0.0.1`，通过 SSH 隧道访问：

```bash
ssh -N -L 3000:127.0.0.1:3000 -L 8080:127.0.0.1:8080 user@your-server
```

### 后台配置步骤

#### 1. 配置 Sub2API

打开：

```text
http://127.0.0.1:8080
```

使用以下文件中的管理员账号密码登录：

```bash
cat "$HOME/ai-gateway/LOCAL_CREDENTIALS.md"
```

然后在 Sub2API 后台完成：

1. 添加 ChatGPT / OpenAI 订阅账号。
2. 添加 Claude 订阅账号。
3. 确认 Sub2API 实际暴露的模型名。
4. 生成给 New API 调用的 API Key。

#### 2. 配置 New API

打开：

```text
http://127.0.0.1:3000
```

首次打开时按页面提示创建 New API 管理员账号。

添加 Sub2API 渠道：

| 字段 | 填写 |
|---|---|
| 类型 | OpenAI / OpenAI Compatible / Responses-compatible，按 New API 当前 UI 为准 |
| 名称 | `sub2api-local` |
| Base URL | `http://host.docker.internal:8080/v1` |
| API Key | Sub2API 后台生成的 Key |
| 模型 | Sub2API 实际暴露的模型名 |

New API 运行在 Docker 容器里，访问宿主机 Sub2API 时不要填 `127.0.0.1:8080`，必须使用：

```text
http://host.docker.internal:8080/v1
```

添加 DeepSeek 渠道：

| 字段 | 填写 |
|---|---|
| 类型 | DeepSeek / OpenAI Compatible |
| Base URL | `https://api.deepseek.com/v1` |
| API Key | 你的 DeepSeek 官方 API Key |
| 模型 | `deepseek-chat`、`deepseek-reasoner` |

#### 3. 模型映射

默认 Codex 请求：

```text
gpt-5-codex
```

如果 New API 或上游没有这个模型，不要假设可用。需要在 New API 里做模型映射：

```text
Codex 请求模型: gpt-5-codex
实际上游模型: Sub2API 或 DeepSeek 真实支持的模型名
```

也可以用实际模型名重新部署或修改 Codex 配置：

```bash
CODEX_MODEL="actual-supported-model" ./scripts/install.sh
```

#### 4. 创建 New API Token

在 New API 后台创建给 Codex 使用的 Token，例如：

| 字段 | 建议 |
|---|---|
| 名称 | `codex-local` |
| 模型权限 | 只开放 Codex 使用的模型 |
| 分组 | `codex` |
| 额度 | 按个人自用设置 |

在启动 Codex 的终端导出：

```bash
export NEWAPI_API_KEY="your-newapi-token"
```

不要把真实 Token 写进 README、Issue、聊天记录或 Git。

### Codex 配置

安装脚本会写入或更新：

```text
$HOME/.codex/config.toml
```

关键配置：

```toml
model = "gpt-5-codex"
model_provider = "newapi"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[model_providers.newapi]
name = "New API Local"
base_url = "http://127.0.0.1:3000/v1"
env_key = "NEWAPI_API_KEY"
wire_api = "responses"
request_max_retries = 2
stream_max_retries = 2
stream_idle_timeout_ms = 300000
```

### 验证

基础验证：

```bash
$HOME/ai-gateway/validate.sh
```

创建 New API Token 后做完整验证：

```bash
export NEWAPI_API_KEY="your-newapi-token"
$HOME/ai-gateway/validate.sh
```

也可以直接测试 Responses API：

```bash
curl http://127.0.0.1:3000/v1/responses \
  -H "Authorization: Bearer $NEWAPI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5-codex",
    "input": "Say hello from New API through local gateway."
  }'
```

成功标准：返回 JSON，并能看到模型输出文本。

### 常见错误

| 错误 | 原因 | 处理 |
|---|---|---|
| `401 unauthorized` | New API Token 错误或 `NEWAPI_API_KEY` 未导出 | 重新导出正确 Token |
| `404 /v1/responses` | New API 或上游不支持 Responses API | 检查/升级 New API 或换支持 Responses 的渠道 |
| `model not found` | 模型名或映射错误 | 在 New API 做模型映射，或修改 `CODEX_MODEL` |
| `502 upstream error` | New API 到上游渠道失败 | 检查 Base URL、Key、模型名、账号状态 |
| New API 访问不到 Sub2API | 渠道里用了 `127.0.0.1:8080` | 改成 `http://host.docker.internal:8080/v1` |
| Docker 不可用 | Docker Desktop / Colima 未启动 | 启动 Docker，例如 `colima start` |
| 端口冲突 | 8080 或 3000 被占用 | 修改端口变量或停止冲突服务 |

### 安全约定

- 默认只绑定 `127.0.0.1`。
- 不要公开暴露 3000/8080。
- 不要提交 `.env`、数据库、日志、Token、Cookie、OAuth 数据、账号密码。
- 订阅账号接入 API 网关可能违反上游条款或触发风控，仅建议个人低频自用。

---

## English

This repository is a reusable one-command deployment kit for a personal AI gateway:

```text
ChatGPT / Claude subscription accounts -> Sub2API -> New API -> Codex App / Codex CLI
DeepSeek official API key              -> New API -> Codex App / Codex CLI
```

Codex calls New API through the OpenAI Responses API:

```text
POST http://127.0.0.1:3000/v1/responses
```

> Note: this repository is the deployment template. The live services are deployed to `$HOME/ai-gateway` by default, not inside the cloned repository.

### Defaults

| Item | Default |
|---|---|
| Gateway home | `$HOME/ai-gateway` |
| Sub2API | `http://127.0.0.1:8080` |
| New API | `http://127.0.0.1:3000` |
| Codex config | `$HOME/.codex/config.toml` |
| Codex skill | `$HOME/.codex/skills/sub2api-newapi-codex/SKILL.md` |
| Local credentials | `$HOME/ai-gateway/LOCAL_CREDENTIALS.md` |

`LOCAL_CREDENTIALS.md` is generated only on the deployed machine, has `600` permissions, and is ignored by Git. It stores the initial Sub2API admin account and password.

### Requirements

- Docker Engine or Docker Desktop
- Docker Compose plugin
- `bash`
- `curl`
- `openssl`
- Optional: `python3`, used for safer Codex config updates

With Colima:

```bash
colima start
```

### Quick Start

```bash
git clone https://github.com/Shuo-O/sub2api-newapi-codex-gateway.git
cd sub2api-newapi-codex-gateway
./scripts/install.sh
```

Open:

```text
Sub2API: http://127.0.0.1:8080
New API: http://127.0.0.1:3000
```

Read the Sub2API admin login:

```bash
cat "$HOME/ai-gateway/LOCAL_CREDENTIALS.md"
```

### Custom Deployment

```bash
AI_GATEWAY_HOME="$HOME/ai-gateway" \
AI_GATEWAY_BIND_HOST="127.0.0.1" \
SUB2API_PORT="8080" \
NEW_API_PORT="3000" \
CODEX_HOME="$HOME/.codex" \
CODEX_MODEL="gpt-5-codex" \
./scripts/install.sh
```

| Variable | Default | Meaning |
|---|---|---|
| `AI_GATEWAY_HOME` | `$HOME/ai-gateway` | Runtime directory |
| `AI_GATEWAY_BIND_HOST` | `127.0.0.1` | Docker published-port bind address |
| `SUB2API_PORT` | `8080` | Sub2API host port |
| `NEW_API_PORT` | `3000` | New API host port |
| `CODEX_HOME` | `$HOME/.codex` | Codex config directory |
| `CODEX_MODEL` | `gpt-5-codex` | Model requested by Codex |
| `INSTALL_CODEX_CONFIG` | `1` | Set to `0` to skip Codex config updates |
| `SUB2API_ADMIN_EMAIL` | `admin@sub2api.local` | Initial Sub2API admin account |
| `SUB2API_ADMIN_PASSWORD` | generated | Initial Sub2API admin password |

For server deployments, keep the services bound to `127.0.0.1` and access them through SSH tunnels:

```bash
ssh -N -L 3000:127.0.0.1:3000 -L 8080:127.0.0.1:8080 user@your-server
```

### Backend Setup

#### 1. Configure Sub2API

Open:

```text
http://127.0.0.1:8080
```

Log in with:

```bash
cat "$HOME/ai-gateway/LOCAL_CREDENTIALS.md"
```

Then:

1. Add ChatGPT / OpenAI subscription accounts.
2. Add Claude subscription accounts.
3. Confirm the actual models exposed by Sub2API.
4. Generate an API key for New API.

#### 2. Configure New API

Open:

```text
http://127.0.0.1:3000
```

Create the New API admin account in the first-run web UI.

Add a Sub2API channel:

| Field | Value |
|---|---|
| Type | OpenAI / OpenAI Compatible / Responses-compatible, depending on the current New API UI |
| Name | `sub2api-local` |
| Base URL | `http://host.docker.internal:8080/v1` |
| API Key | The key generated in Sub2API |
| Models | Actual model names exposed by Sub2API |

New API runs in Docker. To reach Sub2API on the host, use:

```text
http://host.docker.internal:8080/v1
```

Add a DeepSeek channel:

| Field | Value |
|---|---|
| Type | DeepSeek / OpenAI Compatible |
| Base URL | `https://api.deepseek.com/v1` |
| API Key | Your official DeepSeek key |
| Models | `deepseek-chat`, `deepseek-reasoner` |

#### 3. Model Mapping

Codex requests this model by default:

```text
gpt-5-codex
```

If it is unavailable in New API or upstream, create a New API model mapping:

```text
Codex requested model: gpt-5-codex
Actual upstream model: a real Sub2API or DeepSeek model name
```

Or use a real model name:

```bash
CODEX_MODEL="actual-supported-model" ./scripts/install.sh
```

#### 4. Create a New API Token for Codex

Create a New API token for Codex and export it in the shell that starts Codex:

```bash
export NEWAPI_API_KEY="your-newapi-token"
```

Do not commit or share real tokens.

### Codex Config

The installer writes or updates:

```text
$HOME/.codex/config.toml
```

Important provider block:

```toml
model = "gpt-5-codex"
model_provider = "newapi"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[model_providers.newapi]
name = "New API Local"
base_url = "http://127.0.0.1:3000/v1"
env_key = "NEWAPI_API_KEY"
wire_api = "responses"
request_max_retries = 2
stream_max_retries = 2
stream_idle_timeout_ms = 300000
```

### Validation

Basic validation:

```bash
$HOME/ai-gateway/validate.sh
```

Authenticated validation:

```bash
export NEWAPI_API_KEY="your-newapi-token"
$HOME/ai-gateway/validate.sh
```

Direct Responses API test:

```bash
curl http://127.0.0.1:3000/v1/responses \
  -H "Authorization: Bearer $NEWAPI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5-codex",
    "input": "Say hello from New API through local gateway."
  }'
```

Success means the endpoint returns JSON containing model output text.

### Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| `401 unauthorized` | Wrong New API token or missing `NEWAPI_API_KEY` | Export the correct token |
| `404 /v1/responses` | New API or upstream does not support Responses API | Check/upgrade New API or route to a compatible upstream |
| `model not found` | Wrong model name or mapping | Add model mapping or change `CODEX_MODEL` |
| `502 upstream error` | New API cannot reach upstream | Check Base URL, key, model name, and account state |
| New API cannot reach Sub2API | Channel used `127.0.0.1:8080` | Use `http://host.docker.internal:8080/v1` |
| Docker unreachable | Docker Desktop / Colima is stopped | Start Docker, for example `colima start` |
| Port conflict | Port 8080 or 3000 is already used | Change port variables or stop the conflicting service |

### Security

- Bind to `127.0.0.1` by default.
- Do not expose ports 3000/8080 publicly.
- Do not commit `.env`, databases, logs, tokens, cookies, OAuth data, or account passwords.
- Subscription-account API gateways may violate upstream terms or trigger risk controls. Use only for personal, low-frequency, authorized scenarios.
