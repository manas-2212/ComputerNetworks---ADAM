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
PRIMARY_EDGE="${MAC2_IP:-10.7.27.66}"
STANDBY_EDGE="${MAC3_IP:-10.7.24.241}"

echo "=================================================================="
echo "    PHASE 2 EXTENSION E: EDGE MIGRATION & DNS CUTOVER DEMO        "
echo "=================================================================="
echo "Domain:       $TARGET_DOMAIN"
echo "Primary Edge: $PRIMARY_EDGE (Mac 2 — Anant)"
echo "Standby Edge: $STANDBY_EDGE (Mac 3 — Akhil)"
echo "------------------------------------------------------------------"

echo ""
echo "--- STEP 1: Current DNS Target ---"
CURRENT_DNS=$(dig +short "$TARGET_DOMAIN" 2>/dev/null || echo "Not resolving")
echo "  $TARGET_DOMAIN currently resolves to: $CURRENT_DNS"
echo ""

echo "--- STEP 2: Checking Edge Ingress Header ---"
EDGE_HEADER=$(curl -sk --connect-timeout 3 --max-time 5 -I "https://$TARGET_DOMAIN/" 2>/dev/null | grep -i "X-Edge-Proxy" || echo "Header not returned (timeout/connecting)")
echo "  Ingress Proxy: $EDGE_HEADER"
echo ""

echo "------------------------------------------------------------------"
echo "--- STEP 3: Test Direct Connection to Standby Edge (Mac 3) ---"
STANDBY_CHECK=$(curl -sk --connect-timeout 3 --max-time 5 -I "https://$STANDBY_EDGE/" 2>/dev/null | grep -i "X-Edge-Proxy" || echo "Standby Edge unreachable")
echo "  Direct check to Mac 3 ($STANDBY_EDGE): $STANDBY_CHECK"

if echo "$STANDBY_CHECK" | grep -q "nginx-standby-mac3"; then
    echo "  PASS: Standby NGINX is alive and serving traffic on Mac 3!"
else
    echo "  ⚠️ Standby NGINX is not answering on $STANDBY_EDGE:443."
    echo "     Make sure Akhil started it: sudo nginx -c \$(pwd)/config/nginx/nginx-standby.conf"
fi

echo ""
echo "------------------------------------------------------------------"
echo "--- STEP 4: Instructions for Live DNS Cutover ---"
echo "To migrate traffic from Mac 2 (Anant) to Standby Mac 3 (Akhil):"
echo "1. On Mac 1, have Manas open: config/dnsmasq/dnsmasq-phase2-primary.conf"
echo "2. Change: address=/$TARGET_DOMAIN/$PRIMARY_EDGE"
echo "       to: address=/$TARGET_DOMAIN/$STANDBY_EDGE"
echo "3. Manas runs: sudo killall -HUP dnsmasq"
echo "4. Flush client cache: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
echo "5. Re-run this script: $TARGET_DOMAIN will now point to $STANDBY_EDGE"
echo "   and return header: X-Edge-Proxy: nginx-standby-mac3 !"
echo "=================================================================="
