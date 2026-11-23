#!/usr/bin/env bash
# ==============================================================================
# verify-phase1.sh — Comprehensive Pre-Flight Health Check for Phase 1
# Run this BEFORE starting Phase 2 to verify all Phase 1 components work!
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ENV_FILE="$ROOT_DIR/config/network.env"

if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

MAC1_IP="${MAC1_IP:-10.7.17.68}"
MAC2_IP="${MAC2_IP:-10.7.21.52}"
MAC3_IP="${MAC3_IP:-10.7.24.127}"
MAC4_IP="${MAC4_IP:-10.7.13.20}"
DOMAIN="${DOMAIN:-app.team1.test}"

LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 'unknown')"

echo "=================================================================="
echo "        PHASE 1 PRE-FLIGHT VERIFICATION & HEALTH CHECK            "
echo "=================================================================="
echo " Running on: $(whoami)@$(hostname -s) (Local IP: $LOCAL_IP)"
echo " Configured IPs:"
echo "   Mac 1 (Manas, DNS):    $MAC1_IP"
echo "   Mac 2 (Anant, Edge):   $MAC2_IP"
echo "   Mac 3 (Akhil, B-A):    $MAC3_IP"
echo "   Mac 4 (Darain, B-B):   $MAC4_IP"
echo "------------------------------------------------------------------"

PASSED_COUNT=0
TOTAL_CHECKS=6

# Check 1: Ping reachability to other nodes
echo ""
echo "[CHECK 1/6] Layer 3 LAN Ping Reachability..."
PING_FAILS=0
for ip in "$MAC1_IP" "$MAC2_IP" "$MAC3_IP" "$MAC4_IP"; do
    if [ "$ip" = "$LOCAL_IP" ]; then
        continue
    fi
    if ping -c 1 -W 1000 "$ip" >/dev/null 2>&1; then
        echo "   Node $ip is REACHABLE via ICMP ping."
    else
        echo "   Node $ip FAILED to respond to ping. Check Wi-Fi / IP settings."
        PING_FAILS=$((PING_FAILS + 1))
    fi
done
if [ "$PING_FAILS" -eq 0 ]; then
    echo "  -> Check 1 PASSED: All peer machines are reachable on the LAN."
    PASSED_COUNT=$((PASSED_COUNT + 1))
else
    echo "  -> Check 1 WARNING: Some nodes did not reply to ping."
fi

# Check 2: Role-specific local service check
echo ""
echo "[CHECK 2/6] Local Role Service Status..."
case "$LOCAL_IP" in
    "$MAC1_IP")
        echo "  Role: Mac 1 (Manas - DNS Server)"
        if pgrep dnsmasq >/dev/null 2>&1 || lsof -iUDP:53 >/dev/null 2>&1; then
            echo "   dnsmasq is running and listening on port 53."
            RESOLVED=$(dig @127.0.0.1 +short "$DOMAIN" 2>/dev/null || true)
            echo "   Local resolution test: $DOMAIN -> $RESOLVED"
            PASSED_COUNT=$((PASSED_COUNT + 1))
        else
            echo "   dnsmasq is NOT running! Run: sudo brew services start dnsmasq"
        fi
        ;;
    "$MAC2_IP")
        echo "  Role: Mac 2 (Anant - Edge NGINX)"
        if pgrep nginx >/dev/null 2>&1 || lsof -iTCP:443 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "   NGINX is running and listening on port 443."
            PASSED_COUNT=$((PASSED_COUNT + 1))
        else
            echo "   NGINX is NOT running! Run: sudo brew services start nginx"
        fi
        ;;
    "$MAC3_IP")
        echo "  Role: Mac 3 (Akhil - Backend A)"
        if lsof -iTCP:3001 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "   Backend A is listening on port 3001."
            PASSED_COUNT=$((PASSED_COUNT + 1))
        else
            echo "   Backend A is NOT running! Run: ./scripts/start-backend-a.sh"
        fi
        ;;
    "$MAC4_IP")
        echo "  Role: Mac 4 (Darain - Backend B & Client)"
        if lsof -iTCP:3002 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "   Backend B is listening on port 3002."
            PASSED_COUNT=$((PASSED_COUNT + 1))
        else
            echo "   Backend B is NOT running! Run: ./scripts/start-backend-b.sh"
        fi
        ;;
    *)
        echo "  Role: Client node (IP $LOCAL_IP)"
        PASSED_COUNT=$((PASSED_COUNT + 1))
        ;;
esac

# Check 3: Backend A & Backend B Direct Health
echo ""
echo "[CHECK 3/6] Direct Backend Service Responses..."
B_A_RESP=$(curl -s -m 2 "http://$MAC3_IP:3001/api/status" 2>/dev/null || echo "")
B_B_RESP=$(curl -s -m 2 "http://$MAC4_IP:3002/api/status" 2>/dev/null || echo "")

if echo "$B_A_RESP" | grep -q '"backend":"A"'; then
    echo "   Backend A (Akhil, $MAC3_IP:3001) responded: OK"
else
    echo "   Backend A (Akhil, $MAC3_IP:3001) is NOT responding directly."
fi

if echo "$B_B_RESP" | grep -q '"backend":"B"'; then
    echo "   Backend B (Darain, $MAC4_IP:3002) responded: OK"
else
    echo "   Backend B (Darain, $MAC4_IP:3002) is NOT responding directly."
fi

if echo "$B_A_RESP" | grep -q '"backend":"A"' && echo "$B_B_RESP" | grep -q '"backend":"B"'; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
fi

# Check 4: DNS Resolution of Domain Name
echo ""
echo "[CHECK 4/6] DNS Resolution of $DOMAIN..."
DNS_RESULT=$(dig @"$MAC1_IP" +short "$DOMAIN" 2>/dev/null || true)
if [ "$DNS_RESULT" = "$MAC2_IP" ]; then
    echo "   DNS query to $MAC1_IP correctly resolved $DOMAIN -> $DNS_RESULT"
    PASSED_COUNT=$((PASSED_COUNT + 1))
else
    echo "   DNS query to $MAC1_IP FAILED. Expected $MAC2_IP, got: '$DNS_RESULT'"
fi

# Check 5: HTTPS Connection & Certificate Trust
echo ""
echo "[CHECK 5/6] HTTPS Access through Edge NGINX (https://$DOMAIN/)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null || true)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   HTTPS connection succeeded with HTTP 200 OK (Certificate Trusted!)"
    PASSED_COUNT=$((PASSED_COUNT + 1))
else
    echo "   HTTPS connection failed (HTTP Status: $HTTP_CODE)."
    echo "   Trying curl with -k (bypassing cert validation)..."
    HTTP_K_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null || true)
    if [ "$HTTP_K_CODE" = "200" ]; then
        echo "   WARNING: Connection works with -k, meaning your SSL certificate is untrusted."
        echo "   FIX: Add config/certificates/app.team1.test.crt to Keychain Access -> System -> Always Trust."
    fi
fi

# Check 6: Load Balancing & Caching Headers
echo ""
echo "[CHECK 6/6] Load Balancing & HTTP Caching..."
HEADERS=$(curl -sk -I "https://$DOMAIN/api/status" 2>/dev/null || true)
if echo "$HEADERS" | grep -iq "X-Backend:"; then
    BACKEND_SERV=$(echo "$HEADERS" | grep -i "X-Backend:" | tr -d '\r')
    CACHE_CTRL=$(echo "$HEADERS" | grep -i "Cache-Control:" | tr -d '\r')
    echo "   $BACKEND_SERV detected."
    echo "   $CACHE_CTRL detected."
    PASSED_COUNT=$((PASSED_COUNT + 1))
else
    echo "   Could not retrieve X-Backend or Cache-Control headers."
fi

echo ""
echo "------------------------------------------------------------------"
echo " PRE-FLIGHT CHECK SUMMARY: $PASSED_COUNT / $TOTAL_CHECKS Passed."
if [ "$PASSED_COUNT" -eq "$TOTAL_CHECKS" ]; then
    echo " ALL SYSTEMS GO! Phase 1 is 100% verified and operational."
    echo " You are ready to proceed with Phase 2 implementation."
else
    echo " ⚠️  Some Phase 1 checks failed. Resolve the above warnings before starting Phase 2."
fi
echo "=================================================================="
