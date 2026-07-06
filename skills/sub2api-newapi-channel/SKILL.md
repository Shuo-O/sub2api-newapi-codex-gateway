---
name: sub2api-newapi-channel
description: "Use this skill when binding an existing Sub2API deployment into New API for Codex. It focuses on Sub2API API keys, New API channel Base URL, model mapping, New API tokens, and Codex CLI validation."
---

# Sub2API to New API Channel Skill

## Purpose

Configure an already-running Sub2API instance as a New API upstream channel for Codex.

## Inputs

- Sub2API URL on the host: `http://127.0.0.1:8080`
- New API URL on the host: `http://127.0.0.1:3000`
- Sub2API API key generated in the Sub2API UI
- A working upstream model exposed by Sub2API
- Codex-facing model name, usually `gpt-5-codex`

## New API Channel

When New API runs in Docker and Sub2API runs on the same host, set the Sub2API channel Base URL to:

```text
http://host.docker.internal:8080
```

Do not use `127.0.0.1` inside the New API container. If New API logs or Sub2API access logs show `/v1/v1/responses`, remove `/v1` from the channel Base URL.

## Model Mapping

Expose the Codex-facing model in New API, then map it to a model that Sub2API actually supports:

```text
gpt-5-codex -> actual-upstream-model
```

Do not assume `gpt-5-codex` exists upstream. Test the upstream model directly against Sub2API first.

## Codex Tool Compatibility

Codex Responses requests can include an `image_generation` tool declaration even for text tasks. For the Sub2API group used by the API key:

1. Enable image generation for that group.
2. If the setting was changed directly in the database, invalidate Sub2API API key auth cache or restart through the official UI/API path.
3. Validate a minimal request with `tools: [{"type":"image_generation"}]`.

## Validation

Validate New API directly:

```bash
curl http://127.0.0.1:3000/v1/responses \
  -H "Authorization: Bearer $NEWAPI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5-codex","input":"Say hello from New API through local gateway."}'
```

Validate Codex CLI:

```bash
NEWAPI_API_KEY="$NEWAPI_API_KEY" codex exec --ephemeral -s read-only \
  -c approval_policy='"never"' \
  -o /tmp/codex-newapi-last.txt \
  'Reply exactly: CODEX_NEWAPI_OK'
```

Success means `/tmp/codex-newapi-last.txt` contains `CODEX_NEWAPI_OK`.
