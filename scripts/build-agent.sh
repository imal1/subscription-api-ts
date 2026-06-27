#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_DIR="$REPO_ROOT/agent"
OUTPUT_DIR="$REPO_ROOT/dist/agent"

mkdir -p "$OUTPUT_DIR"

echo "Building agent for linux/amd64..."
cd "$AGENT_DIR"
bun build src/server.ts --compile --outfile "$OUTPUT_DIR/miobridge-agent-linux-amd64" --target bun-linux-x64
echo "  -> $OUTPUT_DIR/miobridge-agent-linux-amd64 ($(du -h "$OUTPUT_DIR/miobridge-agent-linux-amd64" | cut -f1))"

echo "Building agent for linux/arm64..."
bun build src/server.ts --compile --outfile "$OUTPUT_DIR/miobridge-agent-linux-arm64" --target bun-linux-arm64
echo "  -> $OUTPUT_DIR/miobridge-agent-linux-arm64 ($(du -h "$OUTPUT_DIR/miobridge-agent-linux-arm64" | cut -f1))"

echo "Done. Binaries in $OUTPUT_DIR"
