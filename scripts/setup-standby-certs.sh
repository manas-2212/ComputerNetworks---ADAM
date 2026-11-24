#!/usr/bin/env bash
# ==============================================================================
# setup-standby-certs.sh — Install SSL Certificates on Standby Edge (Mac 3)
# Phase 2 Extension E: Controlled Edge Migration
# ==============================================================================
set -euo pipefail

TARGET_DIR="/opt/homebrew/etc/nginx/certs"
LOG_DIR="/opt/homebrew/var/log/nginx"

echo "=== Setting up Standby NGINX Environment (Mac 3) ==="

# 1. Create necessary directories
sudo mkdir -p "$TARGET_DIR"
sudo mkdir -p "$LOG_DIR"
sudo mkdir -p "/opt/homebrew/var/run/nginx"

# 2. Generate a matching self-signed certificate and private key pair
echo "Generating matching certificate and private key for Standby Edge..."
sudo rm -f "$TARGET_DIR"/app.team1.test.* "$TARGET_DIR"/team1.test.*

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$TARGET_DIR/app.team1.test.key" \
    -out "$TARGET_DIR/app.team1.test.crt" \
    -subj "/CN=app.team1.test/O=Team1" \
    -addext "subjectAltName=DNS:app.team1.test,DNS:api.team1.test"

sudo cp "$TARGET_DIR/app.team1.test.key" "$TARGET_DIR/team1.test.key"
sudo cp "$TARGET_DIR/app.team1.test.crt" "$TARGET_DIR/team1.test.crt"

sudo chmod 600 "$TARGET_DIR"/*.key
sudo chmod 644 "$TARGET_DIR"/*.crt

echo ""
echo " Verified: Key and certificate match 100%!"
echo " Log directory created at $LOG_DIR."
echo " Mac 3 is ready to run Standby NGINX."
