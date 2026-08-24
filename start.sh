#!/bin/bash
set -e

export NODE_OPTIONS="--max-old-space-size=1024"

if [ -n "$PORT" ]; then
  export N8N_PORT="$PORT"
fi

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

if [ -f "./node_modules/n8n/bin/n8n" ]; then
  exec node --max-old-space-size=1024 ./node_modules/n8n/bin/n8n start
else
  exec n8n start
fi
