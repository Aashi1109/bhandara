#!/usr/bin/env bash

set -euo pipefail

REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
PUBLIC_PORT="${PUBLIC_PORT:-3000}"
APP_PORT="${APP_PORT:-3001}"
WORKER_TYPE="${WORKER_TYPE:-video-processor}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
REDIS_COMMANDER_PORT="${REDIS_COMMANDER_PORT:-8081}"

export REDIS_HOST
export REDIS_PORT
export REDIS_PASSWORD
export REDIS_TLS="${REDIS_TLS:-false}"
REDIS_DB_SESSIONS=1
REDIS_DB_BULL=2
REDIS_DB_ANALYTICS=3
REDIS_DB_RATE_LIMIT=4
REDIS_DB_CACHE=5
REDIS_DB_ACTIVITY=6
export REDIS_COMMANDER_PORT
export PUBLIC_PORT
export APP_PORT
export PORT="${APP_PORT}"
export WORKER_TYPE

mkdir -p /app/logs /app/tmp /app/redis-data
envsubst '${PUBLIC_PORT} ${APP_PORT} ${REDIS_COMMANDER_PORT}' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/nginx.conf

build_redis_commander_hosts() {
  local host="$1"
  local port="$2"
  local password="$3"

  local -a entries=(
    "sessions:${host}:${port}:${REDIS_DB_SESSIONS}"
    "bull:${host}:${port}:${REDIS_DB_BULL}"
    "analytics:${host}:${port}:${REDIS_DB_ANALYTICS}"
    "rate-limit:${host}:${port}:${REDIS_DB_RATE_LIMIT}"
    "cache:${host}:${port}:${REDIS_DB_CACHE}"
    "activity:${host}:${port}:${REDIS_DB_ACTIVITY}"
  )

  if [[ -n "${password}" ]]; then
    for i in "${!entries[@]}"; do
      entries[$i]="${entries[$i]}:${password}"
    done
  fi

  local IFS=,
  printf '%s' "${entries[*]}"
}

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "${value}"
}

build_redis_commander_config_json() {
  local host="$1"
  local port="$2"
  local password="$3"
  local escaped_password
  escaped_password="$(json_escape "${password}")"

  cat <<EOF
{"connections":[
  {"label":"sessions","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_SESSIONS}},
  {"label":"bull","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_BULL}},
  {"label":"analytics","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_ANALYTICS}},
  {"label":"rate-limit","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_RATE_LIMIT}},
  {"label":"cache","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_CACHE}},
  {"label":"activity","host":"${host}","port":"${port}","password":"${escaped_password}","dbIndex":${REDIS_DB_ACTIVITY}}
]}
EOF
}

REDIS_COMMANDER_CONFIG_DIR="$(npm root -g)/redis-commander/config"
mkdir -p "${REDIS_COMMANDER_CONFIG_DIR}"
build_redis_commander_config_json "${REDIS_HOST}" "${REDIS_PORT}" "${REDIS_PASSWORD}" \
  > "${REDIS_COMMANDER_CONFIG_DIR}/local-production.json"

declare -a PIDS=()
declare -A PID_NAMES=()
shutting_down=0

probe_api_server() {
  local attempts=24
  local delay=5

  for ((i=1; i<=attempts; i++)); do
    if [[ "${shutting_down}" -eq 1 ]]; then
      return
    fi

    local response
    response="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:${APP_PORT}/" 2>/dev/null || true)"

    if [[ -n "${response}" && "${response}" != "000" ]]; then
      echo "[probe] api-server reachable on 127.0.0.1:${APP_PORT} with status ${response}"
      return
    fi

    echo "[probe] api-server not reachable on 127.0.0.1:${APP_PORT} yet (attempt ${i}/${attempts})"
    sleep "${delay}"
  done

  echo "[probe] api-server never became reachable on 127.0.0.1:${APP_PORT}"
}

log_database_target() {
  if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "[config] DATABASE_URL is not set"
    return
  fi

  node -e '
    try {
      const parsed = new URL(process.env.DATABASE_URL);
      const summary = {
        protocol: parsed.protocol.replace(/:$/, ""),
        host: parsed.hostname,
        port: parsed.port || "(default)",
        database: parsed.pathname.replace(/^\//, "") || "(none)",
        username: parsed.username || "(none)",
        password: parsed.password ? "***" : "(none)",
      };
      console.log(`[config] DATABASE_URL target ${JSON.stringify(summary)}`);
    } catch {
      console.log("[config] DATABASE_URL is present but could not be parsed");
    }
  '
}

start_process() {
  local name="$1"
  shift

  echo "Starting ${name}..."
  (
    exec > >(sed "s/^/[${name}] /")
    exec 2> >(sed "s/^/[${name}] /" >&2)
    "$@"
  ) &
  local pid=$!
  PIDS+=("${pid}")
  PID_NAMES["${pid}"]="${name}"
  echo "${name} started with pid ${pid}"
}

cleanup() {
  if [[ "${shutting_down}" -eq 1 ]]; then
    return
  fi

  shutting_down=1
  echo "Stopping mono container processes..."

  for pid in "${PIDS[@]:-}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi
  done

  wait || true
}

trap cleanup SIGINT SIGTERM EXIT

log_database_target

start_process \
  "redis" \
  redis-server \
  --bind "${REDIS_HOST}" \
  --port "${REDIS_PORT}" \
  --dir /app/redis-data \
  --save "" \
  --appendonly no

start_process \
  "redis-commander" \
  env \
  -u REDIS_HOST \
  -u REDIS_PORT \
  -u REDIS_PASSWORD \
  -u REDIS_DB \
  -u REDIS_TLS \
  -u REDIS_HOSTS \
  URL_PREFIX="/redis" \
  TRUST_PROXY="true" \
  NODE_ENV="production" \
  redis-commander \
  --port "${REDIS_COMMANDER_PORT}" \
  --address "127.0.0.1" \
  --url-prefix "/redis" \
  --trust-proxy \
  --no-open

start_process "api-server" node index.js
probe_api_server &
start_process "worker" node workers/index.js
start_process "nginx" nginx -g "daemon off;"

monitor_processes() {
  local -A reported=()

  while [[ "${shutting_down}" -eq 0 ]]; do
    for pid in "${PIDS[@]:-}"; do
      if [[ -n "${reported[${pid}]:-}" ]]; then
        continue
      fi

      if ! kill -0 "${pid}" 2>/dev/null; then
        wait "${pid}"
        local exit_code=$?
        local name="${PID_NAMES[${pid}]:-unknown}"
        echo "Process ${name} (pid ${pid}) exited with code ${exit_code}."
        reported["${pid}"]=1
      fi
    done

    sleep 1
  done
}

monitor_processes &
wait
