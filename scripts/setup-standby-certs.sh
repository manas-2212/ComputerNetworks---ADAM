#!/usr/bin/env bash
# ==============================================================================
# setup-standby-certs.sh — Install SSL Certificates on Standby Edge (Mac 3)
# Phase 2 Extension E: Controlled Edge Migration
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
TARGET_DIR="/opt/homebrew/etc/nginx/certs"
REPO_CRT="$ROOT_DIR/config/certificates/app.team1.test.crt"

echo "=== Setting up SSL Certificates for Standby NGINX (Mac 3) ==="

sudo mkdir -p "$TARGET_DIR"

# 1. Copy public certificate from repo
if [ -f "$REPO_CRT" ]; then
    echo "Installing app.team1.test.crt into $TARGET_DIR..."
    sudo cp "$REPO_CRT" "$TARGET_DIR/app.team1.test.crt"
    sudo cp "$REPO_CRT" "$TARGET_DIR/team1.test.crt"
fi

# 2. Check if private key exists; if not, generate self-signed pair for Mac 3
if [ ! -f "$TARGET_DIR/app.team1.test.key" ]; then
    echo "Generating matching private key for Standby Edge on Mac 3..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$TARGET_DIR/app.team1.test.key" \
        -out "$TARGET_DIR/app.team1.test.crt" \
        -subj "/CN=app.team1.test/O=Team1" \
        -addext "subjectAltName=DNS:app.team1.test,DNS:api.team1.test"
    sudo cp "$TARGET_DIR/app.team1.test.key" "$TARGET_DIR/team1.test.key"
    echo "SSL Certificate & Key successfully created in $TARGET_DIR!"
else
    echo "SSL Key already exists in $TARGET_DIR/app.team1.test.key."
fi

sudo chmod 600 "$TARGET_DIR"/*.key
sudo chmod 644 "$TARGET_DIR"/*.crt
echo " Ready! Mac 3 can now safely launch Standby NGINX without certificate errors."
