#!/usr/bin/env bash
set -u

AI_GATEWAY_BIND_HOST="${AI_GATEWAY_BIND_HOST:-127.0.0.1}"
SUB2API_PORT="${SUB2API_PORT:-8080}"
NEW_API_PORT="${NEW_API_PORT:-3000}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5-codex}"

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; }

status=0

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 is installed"
  else
    fail "$1 is missing"
    status=1
  fi
}

check_container() {
  local name="$1"
  local state
  state="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)"
  if [ "$state" = "running" ]; then
    ok "container $name is running"
  elif [ -n "$state" ]; then
    fail "container $name state is $state"
    status=1
  else
    fail "container $name not found"
    status=1
  fi
}

check_port() {
  local port="$1"
  local label="$2"
  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      ok "$label is listening on TCP $port"
      lsof -nP -iTCP:"$port" -sTCP:LISTEN
    else
      fail "$label is not listening on TCP $port"
      status=1
    fi
  else
    warn "lsof is missing; skipped host port inspection for $label"
  fi
}

check_docker_bind() {
  local name="$1"
  local port="$2"
  local label="$3"
  local binding
  binding="$(docker inspect -f "{{range .NetworkSettings.Ports}}{{range .}}{{.HostIp}}:{{.HostPort}}{{end}}{{end}}" "$name" 2>/dev/null || true)"
  if printf '%s\n' "$binding" | grep -qx "${AI_GATEWAY_BIND_HOST}:${port}"; then
    ok "$label Docker port is bound to ${AI_GATEWAY_BIND_HOST}:$port"
  else
    fail "$label Docker port binding is unexpected: ${binding:-missing}"
    status=1
  fi
}

http_code() {
  curl -sS -m 20 -o /tmp/ai-gateway-validate-body.json -w '%{http_code}' "$@" 2>/tmp/ai-gateway-validate-curl.err
}

check_cmd docker
check_cmd curl

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not reachable"
  exit 1
fi
ok "Docker daemon is reachable"

printf '\n== Containers ==\n'
check_container sub2api
check_container sub2api-postgres
check_container sub2api-redis
check_container new-api

printf '\n== Ports ==\n'
check_port "$SUB2API_PORT" "Sub2API"
check_port "$NEW_API_PORT" "New API"
check_docker_bind sub2api "$SUB2API_PORT" "Sub2API"
check_docker_bind new-api "$NEW_API_PORT" "New API"

printf '\n== HTTP ==\n'
sub2api_code="$(http_code "http://127.0.0.1:${SUB2API_PORT}/")"
case "$sub2api_code" in
  2*|3*|401|403) ok "Sub2API root is reachable: HTTP $sub2api_code" ;;
  *) fail "Sub2API root returned HTTP $sub2api_code"; status=1 ;;
esac

newapi_code="$(http_code "http://127.0.0.1:${NEW_API_PORT}/")"
case "$newapi_code" in
  2*|3*|401|403) ok "New API root is reachable: HTTP $newapi_code" ;;
  *) fail "New API root returned HTTP $newapi_code"; status=1 ;;
esac

if [ -z "${NEWAPI_API_KEY:-}" ]; then
  noauth_code="$(
    http_code "http://127.0.0.1:${NEW_API_PORT}/v1/responses" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${CODEX_MODEL}\",\"input\":\"ping\"}"
  )"
  case "$noauth_code" in
    401|403) ok "/v1/responses route is reachable without a token: HTTP $noauth_code" ;;
    404) fail "/v1/responses returned 404 without a token"; status=1 ;;
    *) warn "/v1/responses without a token returned HTTP $noauth_code" ;;
  esac
  warn "NEWAPI_API_KEY is not set; authenticated /v1/responses model test skipped"
else
  responses_code="$(
    http_code "http://127.0.0.1:${NEW_API_PORT}/v1/responses" \
      -H "Authorization: Bearer ${NEWAPI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${CODEX_MODEL}\",\"input\":\"Say hello from New API through local gateway.\"}"
  )"
  case "$responses_code" in
    2*)
      ok "/v1/responses returned HTTP $responses_code"
      printf 'Response body:\n'
      if command -v jq >/dev/null 2>&1; then
        jq . /tmp/ai-gateway-validate-body.json 2>/dev/null || sed -n '1,80p' /tmp/ai-gateway-validate-body.json
      else
        sed -n '1,80p' /tmp/ai-gateway-validate-body.json
      fi
      ;;
    401) fail "/v1/responses returned 401 unauthorized"; status=1 ;;
    404) fail "/v1/responses returned 404"; status=1 ;;
    502) fail "/v1/responses returned 502 upstream error"; status=1 ;;
    *) fail "/v1/responses returned HTTP $responses_code"; sed -n '1,80p' /tmp/ai-gateway-validate-body.json; status=1 ;;
  esac
fi

exit "$status"
