#!/usr/bin/env bash
# ==============================================================================
# test-ha-failover.sh — Test Phase 2 Extension D (High-Availability Failover)
# Run from Client (Darain / Mac 4)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

DOMAIN_URL="https://${DOMAIN:-app.team1.test}/"
ITERATIONS=10

echo "=========================================================="
echo "Phase 2 Extension D: HA Backend Failover Verification"
echo "=========================================================="
echo "Target: $DOMAIN_URL"
echo ""
echo "Sending $ITERATIONS requests..."
echo "Watch the X-Backend header and HTTP response codes:"
echo "----------------------------------------------------------"

for i in $(seq 1 "$ITERATIONS"); do
    RESPONSE=$(curl -sk -i "$DOMAIN_URL" 2>/dev/null || true)
    STATUS=$(echo "$RESPONSE" | grep "HTTP/" | head -1 | awk '{print $2}')
    BACKEND=$(echo "$RESPONSE" | grep -i "X-Backend:" | tr -d '\r' || echo "X-Backend: Unknown")
    echo "Request #$i: Status = $STATUS | Served by: $BACKEND"
    sleep 0.5
done

echo "----------------------------------------------------------"
echo "To demonstrate failover live:"
echo "1. Have Akhil stop Backend A on Mac 3 (Ctrl+C)"
echo "2. Re-run this script immediately."
echo "3. NGINX will automatically detect Backend A is down and seamlessly"
echo "   route 100% of requests to Backend B without throwing 502 Bad Gateway to the user!"
echo "4. Restart Backend A: NGINX automatically restores round-robin distribution."
