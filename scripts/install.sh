#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AI_GATEWAY_HOME="${AI_GATEWAY_HOME:-$HOME/ai-gateway}"
AI_GATEWAY_BIND_HOST="${AI_GATEWAY_BIND_HOST:-127.0.0.1}"
SUB2API_PORT="${SUB2API_PORT:-8080}"
NEW_API_PORT="${NEW_API_PORT:-3000}"
TZ_VALUE="${TZ_VALUE:-Asia/Shanghai}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5-codex}"
INSTALL_CODEX_CONFIG="${INSTALL_CODEX_CONFIG:-1}"
SUB2API_ADMIN_EMAIL="${SUB2API_ADMIN_EMAIL:-admin@sub2api.local}"
SUB2API_ADMIN_PASSWORD="${SUB2API_ADMIN_PASSWORD:-}"

SUB2API_DIR="$AI_GATEWAY_HOME/sub2api-deploy"
NEW_API_DIR="$AI_GATEWAY_HOME/new-api-deploy"
NEW_API_DATA_DIR="$AI_GATEWAY_HOME/new-api-data"
SKILL_DIR="$CODEX_HOME/skills/sub2api-newapi-codex"
CHANNEL_SKILL_DIR="$CODEX_HOME/skills/sub2api-newapi-channel"
CREDENTIALS_FILE="$AI_GATEWAY_HOME/LOCAL_CREDENTIALS.md"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

secret_hex() {
  openssl rand -hex 32
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -q "^${key}=" "$file"; then
    KEY="$key" VALUE="$value" perl -0pi -e 's/^\Q$ENV{KEY}\E=.*/$ENV{KEY} . "=" . $ENV{VALUE}/me' "$file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

write_new_api_compose() {
  mkdir -p "$NEW_API_DIR" "$NEW_API_DATA_DIR"
  cat >"$NEW_API_DIR/docker-compose.yml" <<'YAML'
services:
  new-api:
    image: calciumion/new-api:latest
    container_name: new-api
    restart: unless-stopped
    ports:
      - "${AI_GATEWAY_BIND_HOST:-127.0.0.1}:${NEW_API_PORT:-3000}:3000"
    environment:
      - TZ=${TZ_VALUE:-Asia/Shanghai}
    volumes:
      - ../new-api-data:/data
YAML
  cat >"$NEW_API_DIR/.env" <<EOF_ENV
AI_GATEWAY_BIND_HOST=$AI_GATEWAY_BIND_HOST
NEW_API_PORT=$NEW_API_PORT
TZ_VALUE=$TZ_VALUE
EOF_ENV
}

write_local_credentials() {
  umask 077
  {
    printf '# Local AI Gateway Credentials\n\n'
    printf 'This file is local-only and must not be committed or shared.\n\n'
    printf '## Sub2API\n\n'
    printf -- '- URL: http://127.0.0.1:%s\n' "$SUB2API_PORT"
    printf -- '- Admin account: %s\n' "$SUB2API_ADMIN_EMAIL"
    if [ -n "$SUB2API_ADMIN_PASSWORD" ]; then
      printf -- '- Admin password: %s\n' "$SUB2API_ADMIN_PASSWORD"
    else
      printf -- '- Admin password: check first-start logs with `docker logs sub2api 2>&1 | grep -A1 "Generated admin password"`\n'
    fi
    printf '\n## New API\n\n'
    printf -- '- URL: http://127.0.0.1:%s\n' "$NEW_API_PORT"
    printf -- '- Admin account/password: created manually in the New API first-run web UI\n'
    printf '\nDo not paste real API keys, cookies, OAuth tokens, or account passwords into GitHub, issues, or chat logs.\n'
  } >"$CREDENTIALS_FILE"
  chmod 600 "$CREDENTIALS_FILE"
}

install_codex_skill() {
  mkdir -p "$SKILL_DIR"
  cp "$REPO_ROOT/skills/sub2api-newapi-codex/SKILL.md" "$SKILL_DIR/SKILL.md"
  mkdir -p "$CHANNEL_SKILL_DIR"
  cp "$REPO_ROOT/skills/sub2api-newapi-channel/SKILL.md" "$CHANNEL_SKILL_DIR/SKILL.md"
}

update_codex_config() {
  [ "$INSTALL_CODEX_CONFIG" = "1" ] || return 0
  mkdir -p "$CODEX_HOME"
  local config="$CODEX_HOME/config.toml"
  local backup
  if [ -f "$config" ]; then
    backup="$config.backup-ai-gateway-$(date +%Y%m%d%H%M%S)"
    cp "$config" "$backup"
    printf 'Backed up Codex config to %s\n' "$backup"
  else
    : >"$config"
    chmod 600 "$config" || true
  fi

  if command -v python3 >/dev/null 2>&1; then
    CONFIG="$config" CODEX_MODEL="$CODEX_MODEL" NEW_API_PORT="$NEW_API_PORT" SKILL_DIR="$SKILL_DIR" CHANNEL_SKILL_DIR="$CHANNEL_SKILL_DIR" python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["CONFIG"])
text = path.read_text() if path.exists() else ""

def set_top_level(src: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}\s*=.*$", re.M)
    line = f'{key} = {value}'
    if pattern.search(src):
        return pattern.sub(line, src, count=1)
    return line + "\n" + src

for key, value in {
    "model": f'"{os.environ["CODEX_MODEL"]}"',
    "model_provider": '"newapi"',
    "approval_policy": '"on-request"',
    "sandbox_mode": '"workspace-write"',
}.items():
    text = set_top_level(text, key, value)

text = re.sub(r"\n\[model_providers\.newapi\]\n(?:[^\n[]|\n(?!\[))*", "\n", text, flags=re.M)
text = re.sub(r'\n\[\[skills\.config\]\]\npath = "' + re.escape(os.environ["SKILL_DIR"]) + r'"\nenabled = true\n?', "\n", text)
text = re.sub(r'\n\[\[skills\.config\]\]\npath = "' + re.escape(os.environ["CHANNEL_SKILL_DIR"]) + r'"\nenabled = true\n?', "\n", text)

provider = f'''
[model_providers.newapi]
name = "New API Local"
base_url = "http://127.0.0.1:{os.environ["NEW_API_PORT"]}/v1"
env_key = "NEWAPI_API_KEY"
wire_api = "responses"
request_max_retries = 2
stream_max_retries = 2
stream_idle_timeout_ms = 300000

[[skills.config]]
path = "{os.environ["SKILL_DIR"]}"
enabled = true

[[skills.config]]
path = "{os.environ["CHANNEL_SKILL_DIR"]}"
enabled = true
'''

path.write_text(text.rstrip() + "\n" + provider)
PY
  else
    cat >>"$config" <<EOF_TOML

model = "$CODEX_MODEL"
model_provider = "newapi"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[model_providers.newapi]
name = "New API Local"
base_url = "http://127.0.0.1:$NEW_API_PORT/v1"
env_key = "NEWAPI_API_KEY"
wire_api = "responses"
request_max_retries = 2
stream_max_retries = 2
stream_idle_timeout_ms = 300000

[[skills.config]]
path = "$SKILL_DIR"
enabled = true

[[skills.config]]
path = "$CHANNEL_SKILL_DIR"
enabled = true
EOF_TOML
  fi
}

main() {
  need_cmd docker
  need_cmd curl
  need_cmd openssl
  need_cmd perl

  if ! docker info >/dev/null 2>&1; then
    printf 'Docker daemon is not reachable. Start Docker Desktop or Colima first.\n' >&2
    exit 1
  fi

  mkdir -p "$AI_GATEWAY_HOME" "$SUB2API_DIR"

  printf 'Installing gateway into %s\n' "$AI_GATEWAY_HOME"

  curl -fsSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/docker-compose.local.yml -o "$SUB2API_DIR/docker-compose.yml"
  curl -fsSL https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy/.env.example -o "$SUB2API_DIR/.env.example"

  if [ ! -f "$SUB2API_DIR/.env" ]; then
    cp "$SUB2API_DIR/.env.example" "$SUB2API_DIR/.env"
    chmod 600 "$SUB2API_DIR/.env"
    set_env_value "$SUB2API_DIR/.env" POSTGRES_PASSWORD "$(secret_hex)"
    set_env_value "$SUB2API_DIR/.env" JWT_SECRET "$(secret_hex)"
    set_env_value "$SUB2API_DIR/.env" TOTP_ENCRYPTION_KEY "$(secret_hex)"
    if [ -z "$SUB2API_ADMIN_PASSWORD" ]; then
      SUB2API_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
    fi
  fi

  set_env_value "$SUB2API_DIR/.env" BIND_HOST "$AI_GATEWAY_BIND_HOST"
  set_env_value "$SUB2API_DIR/.env" SERVER_PORT "$SUB2API_PORT"
  set_env_value "$SUB2API_DIR/.env" TZ "$TZ_VALUE"
  set_env_value "$SUB2API_DIR/.env" ADMIN_EMAIL "$SUB2API_ADMIN_EMAIL"
  if [ -n "$SUB2API_ADMIN_PASSWORD" ]; then
    set_env_value "$SUB2API_DIR/.env" ADMIN_PASSWORD "$SUB2API_ADMIN_PASSWORD"
  fi

  mkdir -p "$SUB2API_DIR/data" "$SUB2API_DIR/postgres_data" "$SUB2API_DIR/redis_data"

  write_new_api_compose
  cp "$REPO_ROOT/scripts/validate.sh" "$AI_GATEWAY_HOME/validate.sh"
  chmod +x "$AI_GATEWAY_HOME/validate.sh"
  write_local_credentials

  install_codex_skill
  update_codex_config

  (cd "$SUB2API_DIR" && docker compose up -d)
  (cd "$NEW_API_DIR" && docker compose up -d)

  printf '\nDeployment finished.\n'
  printf 'Sub2API: http://127.0.0.1:%s\n' "$SUB2API_PORT"
  printf 'New API: http://127.0.0.1:%s\n' "$NEW_API_PORT"
  printf 'Validate: %s/validate.sh\n' "$AI_GATEWAY_HOME"
  printf 'Local credentials: %s\n' "$CREDENTIALS_FILE"
  printf '\nNext: open both web UIs, configure accounts/channels/tokens, then export NEWAPI_API_KEY and rerun validation.\n'
}

main "$@"
