---
name: sub2api-newapi-codex
description: "Use this skill when deploying, configuring, validating, or troubleshooting the Sub2API + New API + Codex gateway. It covers Docker deployment, New API channel setup, Codex Responses API provider configuration, and local/server validation."
---

# Sub2API + New API + Codex Gateway

## Purpose

Maintain a personal gateway where:

- ChatGPT / Claude subscription accounts are configured in Sub2API.
- DeepSeek official API keys are configured directly in New API.
- New API is the single Codex provider.
- Codex uses `wire_api = "responses"` and calls `POST /v1/responses`.

## Deployment Defaults

- Gateway home: `$HOME/ai-gateway`
- Sub2API: `127.0.0.1:8080`
- New API: `127.0.0.1:3000`
- Codex config: `$HOME/.codex/config.toml`
- New API channel URL for Sub2API: `http://host.docker.internal:8080`
- Codex provider base URL: `http://127.0.0.1:3000/v1`
- Focused channel setup skill: `sub2api-newapi-channel`

## Commands

Install or repair:

```bash
./scripts/install.sh
```

Validate:

```bash
$HOME/ai-gateway/validate.sh
```

Authenticated validation:

```bash
export NEWAPI_API_KEY="your-newapi-token"
$HOME/ai-gateway/validate.sh
```

## Rules

1. Do not store real API keys, cookies, OAuth tokens, account passwords, or browser session files.
2. Keep the default deployment bound to localhost.
3. For server use, prefer SSH tunnels over public exposure.
4. Do not claim Codex compatibility until `POST /v1/responses` works.
5. If `gpt-5-codex` is unavailable upstream, configure New API model mapping or change `CODEX_MODEL`.

## Troubleshooting

- `401 unauthorized`: wrong New API token or `NEWAPI_API_KEY` is missing.
- `404 /v1/responses`: New API or upstream does not expose Responses API.
- `model not found`: model name or New API mapping is wrong.
- `502 upstream error`: New API channel configuration or upstream account state is wrong.
- New API cannot reach Sub2API: use `http://host.docker.internal:8080`, not `127.0.0.1`.
- Upstream logs show `/v1/v1/responses`: remove `/v1` from the New API Sub2API channel Base URL.
- Codex CLI returns `Image generation is not enabled for this group`: enable Sub2API group image generation for the group used by the API key, then invalidate the Sub2API API key auth cache.
