#!/bin/bash
set -e

# Auto-detect container RAM (cgroup v2 / v1) and set V8 heap to 75% (default 768MB for 1GB container)
HEAP_MB=768
if [ -f /sys/fs/cgroup/memory.max ]; then
  RAW_MEM=$(cat /sys/fs/cgroup/memory.max)
  if [ "$RAW_MEM" != "max" ] && [ "$RAW_MEM" -gt 0 ] 2>/dev/null; then
    TOTAL_MB=$((RAW_MEM / 1024 / 1024))
    if [ "$TOTAL_MB" -le 4096 ]; then
      HEAP_MB=$((TOTAL_MB * 3 / 4))
    fi
  fi
elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
  RAW_MEM=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
  if [ "$RAW_MEM" -gt 0 ] 2>/dev/null; then
    TOTAL_MB=$((RAW_MEM / 1024 / 1024))
    if [ "$TOTAL_MB" -le 4096 ]; then
      HEAP_MB=$((TOTAL_MB * 3 / 4))
    fi
  fi
fi

export NODE_OPTIONS="--max-old-space-size=${HEAP_MB}"

if [ -n "$PORT" ]; then
  export N8N_PORT="$PORT"
fi

# Global Execution & Backend Speed Defaults
export EXECUTIONS_DATA_SAVE_ON_SUCCESS="${EXECUTIONS_DATA_SAVE_ON_SUCCESS:-none}"
export EXECUTIONS_DATA_SAVE_ON_ERROR="${EXECUTIONS_DATA_SAVE_ON_ERROR:-all}"
export EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS="${EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS:-false}"
export EXECUTIONS_DATA_SAVE_ON_PROGRESS="${EXECUTIONS_DATA_SAVE_ON_PROGRESS:-false}"
export EXECUTIONS_DATA_PRUNE="${EXECUTIONS_DATA_PRUNE:-true}"
export EXECUTIONS_DATA_MAX_AGE="${EXECUTIONS_DATA_MAX_AGE:-72}"
export EXECUTIONS_DATA_PRUNE_MAX_COUNT="${EXECUTIONS_DATA_PRUNE_MAX_COUNT:-500}"
export N8N_DEFAULT_BINARY_DATA_MODE="${N8N_DEFAULT_BINARY_DATA_MODE:-filesystem}"
export N8N_PAYLOAD_SIZE_MAX="${N8N_PAYLOAD_SIZE_MAX:-32}"
export DB_POSTGRESDB_POOL_SIZE="${DB_POSTGRESDB_POOL_SIZE:-10}"
export N8N_METRICS="${N8N_METRICS:-false}"
export N8N_DIAGNOSTICS_ENABLED="${N8N_DIAGNOSTICS_ENABLED:-false}"
export N8N_VERSION_NOTIFICATIONS_ENABLED="${N8N_VERSION_NOTIFICATIONS_ENABLED:-false}"
export GENERIC_TIMEZONE="${GENERIC_TIMEZONE:-Asia/Kolkata}"
export TZ="${TZ:-Asia/Kolkata}"

eval "$(node -e '
  const raw = process.env.SCALINGO_POSTGRESQL_URL || process.env.DATABASE_URL;
  if (raw && !raw.startsWith("$")) {
    try {
      const url = new URL(raw);
      console.log(`export DB_TYPE=postgresdb`);
      console.log(`export DB_POSTGRESDB_HOST="${url.hostname}"`);
      console.log(`export DB_POSTGRESDB_PORT="${url.port || 5432}"`);
      console.log(`export DB_POSTGRESDB_DATABASE="${url.pathname.replace(/^\//, "")}"`);
      console.log(`export DB_POSTGRESDB_USER="${decodeURIComponent(url.username)}"`);
      console.log(`export DB_POSTGRESDB_PASSWORD="${decodeURIComponent(url.password)}"`);
      console.log(`export DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false`);
    } catch(err) {
      console.error("DB URL parse error:", err);
    }
  }
')"

eval "$(node -e '
  const raw = process.env.SCALINGO_REDIS_URL || process.env.REDIS_URL;
  if (raw && !raw.startsWith("$")) {
    try {
      const url = new URL(raw);
      console.log(`export QUEUE_BULL_REDIS_HOST="${url.hostname}"`);
      console.log(`export QUEUE_BULL_REDIS_PORT="${url.port || 6379}"`);
      console.log(`export REDIS_HOST="${url.hostname}"`);
      console.log(`export REDIS_PORT="${url.port || 6379}"`);
      if (url.password) {
        const pass = decodeURIComponent(url.password);
        console.log(`export QUEUE_BULL_REDIS_PASSWORD="${pass}"`);
        console.log(`export REDIS_PASSWORD="${pass}"`);
      }
      if (url.username && url.username !== "default") {
        console.log(`export QUEUE_BULL_REDIS_USERNAME="${decodeURIComponent(url.username)}"`);
      }
      if (url.protocol === "rediss:") {
        console.log(`export QUEUE_BULL_REDIS_TLS=true`);
      }
    } catch(err) {
      console.error("Redis URL parse error:", err);
    }
  }
')"

node -e '
  const pkg = require("./package.json");
  const fs = require("fs");
  const path = require("path");
  const customDir = path.join(process.env.HOME, ".n8n", "custom", "node_modules");
  fs.mkdirSync(customDir, { recursive: true });
  for (const dep of Object.keys(pkg.dependencies || {})) {
    if (dep === "n8n" || dep === "n8n-nodes-base") continue;
    const src = path.resolve("node_modules", dep);
    if (!fs.existsSync(src)) continue;
    const dest = path.join(customDir, dep);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    try { fs.unlinkSync(dest); } catch {}
    fs.symlinkSync(src, dest, "junction");
  }
'
export N8N_CUSTOM_EXTENSIONS="$HOME/.n8n/custom"

N8N_BIN="n8n"
if [ -f "./node_modules/n8n/bin/n8n" ]; then
  N8N_BIN="node --max-old-space-size=${HEAP_MB} ./node_modules/n8n/bin/n8n"
fi

if [ "$1" = "worker" ]; then
  exec $N8N_BIN worker --concurrency="${N8N_WORKER_CONCURRENCY:-5}"
fi

exec $N8N_BIN start
