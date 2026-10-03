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

if [ -f "./node_modules/n8n/bin/n8n" ]; then
  exec node --max-old-space-size=1024 ./node_modules/n8n/bin/n8n start
else
  exec n8n start
fi
