# Sub2API + New API + Codex Local Gateway

This repository packages a one-command deployment kit for a personal AI gateway:

```text
ChatGPT / Claude subscription accounts -> Sub2API -> New API -> Codex App / Codex CLI
DeepSeek official API key              -> New API -> Codex App / Codex CLI
```

The deployed Codex provider uses the OpenAI Responses API:

```text
POST http://127.0.0.1:3000/v1/responses
```

The default deployment is localhost-only. Keep it private unless you deliberately add your own firewall, TLS, authentication, and access controls.

## What This Installs

The installer creates a gateway directory, downloads the upstream Sub2API Docker Compose files, writes a New API Compose file, starts both services, installs a Codex skill, and can update the local Codex config.

Default paths:

| Item | Default |
|---|---|
| Gateway home | `$HOME/ai-gateway` |
| Sub2API | `127.0.0.1:8080` |
| New API | `127.0.0.1:3000` |
| Codex config | `$HOME/.codex/config.toml` |
| Codex skill | `$HOME/.codex/skills/sub2api-newapi-codex/SKILL.md` |
| Local credentials | `$HOME/ai-gateway/LOCAL_CREDENTIALS.md` |

You can override paths and ports with environment variables before running the installer.

## Requirements

- Docker Engine or Docker Desktop
- Docker Compose plugin
- `curl`
- `openssl`
- `bash`
- Optional: `python3`, used for safer Codex config updates

On macOS with Colima:

```bash
colima start
```

## Quick Start

```bash
git clone https://github.com/Shuo-O/sub2api-newapi-codex-gateway.git
cd sub2api-newapi-codex-gateway
./scripts/install.sh
```

After installation, open:

```text
Sub2API: http://127.0.0.1:8080
New API: http://127.0.0.1:3000
```

Run validation:

```bash
$HOME/ai-gateway/validate.sh
```

Without a New API token, the validator should still prove that `/v1/responses` exists by returning `401`.

## Custom Deployment

Set variables before running `install.sh`:

```bash
AI_GATEWAY_HOME="$HOME/ai-gateway" \
AI_GATEWAY_BIND_HOST="127.0.0.1" \
SUB2API_PORT="8080" \
NEW_API_PORT="3000" \
CODEX_HOME="$HOME/.codex" \
./scripts/install.sh
```

Useful variables:

| Variable | Default | Meaning |
|---|---|---|
| `AI_GATEWAY_HOME` | `$HOME/ai-gateway` | Deployment directory |
| `AI_GATEWAY_BIND_HOST` | `127.0.0.1` | Host interface for Docker-published ports |
| `SUB2API_PORT` | `8080` | Host port for Sub2API |
| `NEW_API_PORT` | `3000` | Host port for New API |
| `CODEX_HOME` | `$HOME/.codex` | Codex config directory |
| `CODEX_MODEL` | `gpt-5-codex` | Model name Codex will request |
| `INSTALL_CODEX_CONFIG` | `1` | Set to `0` to skip Codex config updates |
| `SUB2API_ADMIN_EMAIL` | `admin@sub2api.local` | Initial Sub2API admin account for new installs |
| `SUB2API_ADMIN_PASSWORD` | generated | Initial Sub2API admin password for new installs |

For a server deployment, keep `AI_GATEWAY_BIND_HOST=127.0.0.1` and access it through SSH tunnels:

```bash
ssh -N -L 3000:127.0.0.1:3000 -L 8080:127.0.0.1:8080 user@your-server
```

Then open local browser URLs:

```text
http://127.0.0.1:8080
http://127.0.0.1:3000
```

## Manual Backend Configuration

The installer starts the services. You still need to configure accounts and API keys in the web UIs.

### 1. Configure Sub2API

Open:

```text
http://127.0.0.1:8080
```

In Sub2API:

1. Complete admin initialization or login.
2. Add ChatGPT / OpenAI subscription accounts.
3. Add Claude subscription accounts.
4. Confirm the actual models exposed by Sub2API.
5. Generate an API key for New API.

Do not save real account credentials, cookies, OAuth tokens, or API keys in this repository.

For a fresh install, the installer writes the local-only admin credential file:

```bash
cat "$HOME/ai-gateway/LOCAL_CREDENTIALS.md"
```

This file is generated on the deployed machine, has `600` permissions, and is ignored by Git. It is intentionally not included in this repository or uploaded to GitHub.

If you installed before this credentials file existed, retrieve the one-time Sub2API password from local Docker logs:

```bash
docker logs sub2api 2>&1 | grep -A1 'Generated admin password'
```

### 2. Configure New API

Open:

```text
http://127.0.0.1:3000
```

Complete admin initialization or login.

Add a Sub2API channel:

| Field | Value |
|---|---|
| Type | OpenAI / OpenAI Compatible / Responses-compatible, depending on the current New API UI |
| Name | `sub2api-local` |
| Base URL | `http://host.docker.internal:8080/v1` |
| API Key | The key generated in Sub2API |
| Models | The actual model names exposed by Sub2API |

Important: New API runs in Docker. Inside the New API container, `127.0.0.1:8080` means the New API container itself, not the host. Use:

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

### 3. Configure Model Mapping

Codex requests this model by default:

```text
gpt-5-codex
```

If `gpt-5-codex` is not available in New API or the selected upstream, configure a New API model mapping:

```text
Codex requested model: gpt-5-codex
Actual upstream model: the real Sub2API or DeepSeek model name
```

Alternatively, rerun the installer with a real upstream model:

```bash
CODEX_MODEL="actual-supported-model" ./scripts/install.sh
```

### 4. Create the New API Token for Codex

In New API, create a token for Codex. Suggested values:

| Field | Suggested value |
|---|---|
| Name | `codex-local` |
| Model access | Only the model or mapped model used by Codex |
| Group | `codex` |
| Quota | Personal-use amount |

Export the token in the shell that starts Codex:

```bash
export NEWAPI_API_KEY="your-newapi-token"
```

Do not put the real token in documentation or commits.

## Codex Config

The installer writes or updates:

```text
$HOME/.codex/config.toml
```

Expected provider block:

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

The real New API token is read from `NEWAPI_API_KEY`; it is not stored in `config.toml`.

## Validation

Basic validation:

```bash
$HOME/ai-gateway/validate.sh
```

Authenticated Responses API validation:

```bash
export NEWAPI_API_KEY="your-newapi-token"
$HOME/ai-gateway/validate.sh
```

Direct curl check:

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

## Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| `401 unauthorized` | Wrong New API token or `NEWAPI_API_KEY` missing in the current shell | Export the correct New API token |
| `404 /v1/responses` | New API or selected upstream does not support Responses API | Upgrade/check New API or route to a Responses-compatible upstream |
| `model not found` | Model name or New API mapping is wrong | Add model mapping or change `CODEX_MODEL` |
| `502 upstream error` | New API cannot reach Sub2API / DeepSeek or upstream rejected request | Check channel Base URL, API key, model name, and account state |
| New API cannot reach Sub2API | New API channel used `127.0.0.1:8080` | Use `http://host.docker.internal:8080/v1` |
| Docker unreachable | Docker Desktop or Colima is stopped | Start Docker, for example `colima start` |
| Port conflict | Another process uses `8080` or `3000` | Change `SUB2API_PORT` / `NEW_API_PORT` or stop the conflicting service |

## Security

- Keep services bound to localhost unless you add production-grade security yourself.
- Do not publish subscription-account-backed APIs.
- Do not commit `.env`, SQLite databases, logs, tokens, cookies, OAuth data, or account credentials.
- Subscription-account-to-API gateways may violate upstream terms or trigger risk controls. Use only for personal, low-frequency, authorized scenarios.
