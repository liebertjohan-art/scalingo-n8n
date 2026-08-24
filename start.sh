#!/bin/bash
set -e

if [ -n "$PORT" ]; then
  export N8N_PORT="$PORT"
fi

PG_URL="${SCALINGO_POSTGRESQL_URL:-$DATABASE_URL}"
if [ -n "$PG_URL" ]; then
  eval "$(node -e '
    try {
      const url = new URL(process.env.PG_URL);
      console.log(`export DB_TYPE=postgresdb`);
      console.log(`export DB_POSTGRESDB_HOST="${url.hostname}"`);
      console.log(`export DB_POSTGRESDB_PORT="${url.port || 5432}"`);
      console.log(`export DB_POSTGRESDB_DATABASE="${url.pathname.replace(/^\//, "")}"`);
      console.log(`export DB_POSTGRESDB_USER="${decodeURIComponent(url.username)}"`);
      console.log(`export DB_POSTGRESDB_PASSWORD="${decodeURIComponent(url.password)}"`);
      console.log(`export DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false`);
    } catch(e) {}
  ')"
fi

exec n8n start
