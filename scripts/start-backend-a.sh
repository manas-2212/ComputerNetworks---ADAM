#!/usr/bin/env bash
#
# start-backend-a.sh — start Backend A (Akhil, 10.7.4.37:3001)
#
# Usage (from anywhere in the repo):
#   ./scripts/start-backend-a.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/../backends/backend-a"
PORT=3001

# 1. Check that Node.js and npm are installed
if ! command -v node >/dev/null 2>&1; then
  echo "Error: Node.js is not installed. Install it from https://nodejs.org" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is not installed." >&2
  exit 1
fi

cd "$BACKEND_DIR"

# 2. Install dependencies (express) if they are missing
if [ ! -d node_modules ]; then
  echo "Installing dependencies..."
  npm install
fi

# 3. Make sure nothing else is already using port 3001
if command -v lsof >/dev/null 2>&1 && lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Error: port $PORT is already in use:" >&2
  lsof -iTCP:"$PORT" -sTCP:LISTEN >&2
  exit 1
fi

# 4. Show this machine's LAN IP so it can be checked against the NGINX upstream
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || true)"
echo "Starting Backend A on 0.0.0.0:$PORT"
if [ -n "${LAN_IP:-}" ]; then
  echo "Reachable on the LAN at http://$LAN_IP:$PORT (expected: 10.7.4.37)"
fi

# 5. Start the server (Ctrl+C to stop)
exec node server.js