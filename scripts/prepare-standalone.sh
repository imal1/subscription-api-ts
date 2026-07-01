#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STANDALONE="$ROOT_DIR/frontend/.next/standalone"
RUNTIME="$STANDALONE/frontend"

if [[ ! -f "$RUNTIME/server.js" ]]; then
  echo "standalone server.js not found; run frontend build first" >&2
  exit 1
fi

rm -rf "$RUNTIME/.next/static"
mkdir -p "$RUNTIME/.next"
cp -r "$ROOT_DIR/frontend/.next/static" "$RUNTIME/.next/static"

rm -rf "$RUNTIME/public"
if [[ -d "$ROOT_DIR/frontend/public" ]]; then
  cp -r "$ROOT_DIR/frontend/public" "$RUNTIME/public"
fi

echo "standalone static assets prepared"
