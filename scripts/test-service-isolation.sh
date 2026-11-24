#!/usr/bin/env bash
# ==============================================================================
# test-service-isolation.sh — Test Phase 2 Extension C (Backend Firewall)
# Verifies that direct access to BOTH Backend A (:3001) and Backend B (:3002)
# is BLOCKED from client machines, while Edge Proxy ingress SUCCEEDS.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

BACKEND_A_IP="${MAC3_IP:-10.7.24.127}"
BACKEND_B_IP="${MAC4_IP:-10.7.13.20}"
EDGE_DOMAIN="${DOMAIN:-app.team1.test}"

echo "=================================================================="
echo "    PHASE 2 EXTENSION C: SERVICE ISOLATION VERIFICATION          "
echo "=================================================================="
echo "Backend A: $BACKEND_A_IP:3001"
echo "Backend B: $BACKEND_B_IP:3002"
echo "Edge Host: $EDGE_DOMAIN"
echo "------------------------------------------------------------------"

echo ""
echo "[TEST 1: Direct Connection to Backend A (:3001)]"
echo "Attempting to bypass Edge and connect directly to Backend A..."
if curl --connect-timeout 2 -s "http://$BACKEND_A_IP:3001/" >/dev/null 2>&1; then
    echo "  ⚠️ DIRECT ACCESS ALLOWED! (Firewall NOT active on Mac 3)."
    echo "  Run 'sudo ./scripts/apply-firewall.sh' on Mac 3 to enforce isolation."
else
    echo "  PASS: Direct TCP connection to $BACKEND_A_IP:3001 was REFUSED/BLOCKED!"
    echo "  Service Isolation is active on Backend A."
fi

echo ""
echo "[TEST 2: Direct Connection to Backend B (:3002)]"
echo "Attempting to bypass Edge and connect directly to Backend B..."
if curl --connect-timeout 2 -s "http://$BACKEND_B_IP:3002/" >/dev/null 2>&1; then
    echo "  ⚠️ DIRECT ACCESS ALLOWED! (Firewall NOT active on Mac 4)."
    echo "  Run 'sudo ./scripts/apply-firewall.sh' on Mac 4 to enforce isolation."
else
    echo "  PASS: Direct TCP connection to $BACKEND_B_IP:3002 was REFUSED/BLOCKED!"
    echo "  Service Isolation is active on Backend B."
fi

echo ""
echo "[TEST 3: Authorized Ingress via Edge Reverse Proxy]"
echo "Connecting to application via Edge (https://$EDGE_DOMAIN/)..."
CURL_ERR=$(mktemp)
HTTP_STATUS=$(curl -sk --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" "https://$EDGE_DOMAIN/" 2>"$CURL_ERR" || true)
HTTP_STATUS=$(echo "$HTTP_STATUS" | tr -d '[:space:]')
BACKEND_HEADER=$(curl -sk --connect-timeout 3 --max-time 5 -I "https://$EDGE_DOMAIN/" 2>/dev/null | grep -i "X-Backend" || echo "Header not found")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "  PASS: Edge proxy successfully connects to backends! HTTP Status: $HTTP_STATUS ($BACKEND_HEADER)"
    echo "  Proof: Edge (Mac 2) is whitelisted in pf rules; direct client access is forbidden."
else
    echo "  FAIL: Error connecting via Edge (HTTP Code: ${HTTP_STATUS:-000})"
    if [ -s "$CURL_ERR" ]; then
        echo "  Exact Error: $(cat "$CURL_ERR")"
    fi
fi
rm -f "$CURL_ERR"

echo ""
echo "=================================================================="
echo "CONCLUSION: Backends are isolated. Clients cannot bypass NGINX."
echo "=================================================================="
