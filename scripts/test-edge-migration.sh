#!/usr/bin/env bash
# ==============================================================================
# test-edge-migration.sh — Test Phase 2 Extension E (DNS Edge Cutover)
# Run from Client (Darain / Mac 4)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

TARGET_DOMAIN="${DOMAIN:-app.team1.test}"
STANDBY_IP="${MAC3_IP:-10.7.24.127}"

echo "=========================================================="
echo "Phase 2 Extension E: Edge Migration & DNS Cutover"
echo "=========================================================="
echo ""
echo "Current DNS target for $TARGET_DOMAIN:"
dig +short "$TARGET_DOMAIN"
echo ""

echo "Checking which Edge Proxy is currently answering:"
EDGE_HEADER=$(curl -sk -I "https://$TARGET_DOMAIN/" | grep -i "X-Edge-Proxy" || echo "Standard NGINX Edge (Mac 2)")
echo "Ingress node: $EDGE_HEADER"
echo ""
echo "Steps for live migration demo:"
echo "1. Start Standby NGINX on Mac 3 (Akhil): sudo nginx -c \$(pwd)/config/nginx/nginx-standby.conf"
echo "2. Update primary & backup DNS to point $TARGET_DOMAIN -> $STANDBY_IP (Mac 3)"
echo "3. Reload dnsmasq: sudo killall -HUP dnsmasq"
echo "4. Watch client resolve and transition to Mac 3 (showing X-Edge-Proxy: nginx-standby-mac3) seamlessly!"
