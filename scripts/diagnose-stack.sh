#!/usr/bin/env bash
# ==============================================================================
# diagnose-stack.sh — Systematic Layer-by-Layer Network Diagnostics
# Phase 2 Extension F: Fault Isolation and Troubleshooting Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

PRIMARY_DNS="${MAC1_IP:-10.7.17.68}"
EDGE_IP="${MAC2_IP:-10.7.21.52}"
BACKUP_DNS="${MAC4_IP:-10.7.13.20}"
DOMAIN="${DOMAIN:-app.team1.test}"
EDGE_PORT=443

echo "=================================================================="
echo "    TEAM ADAM — LAYER-BY-LAYER SYSTEMATIC DIAGNOSTIC TOOL"
echo "=================================================================="

# LAYER 1: DNS LAYER
echo ""
echo "[LAYER 1: DNS RESOLUTION]"
echo "Checking if $DOMAIN resolves..."

DNS_RES=$(dig +short "$DOMAIN" 2>/dev/null || true)
if [ -z "$DNS_RES" ]; then
    echo " FAIL: Local system cannot resolve $DOMAIN."
    echo "  -> Isolating DNS: Testing direct query to Primary DNS ($PRIMARY_DNS)..."
    P_RES=$(dig @"$PRIMARY_DNS" +short "$DOMAIN" 2>/dev/null || true)
    if [ -n "$P_RES" ]; then
        echo "     Primary DNS ($PRIMARY_DNS) is UP and returned: $P_RES"
        echo "     DIAGNOSIS: Local client DNS resolver setting is wrong! Add $PRIMARY_DNS to Network Settings."
    else
        echo "     Primary DNS ($PRIMARY_DNS) is DOWN or unresponsive."
        echo "  -> Testing Backup DNS ($BACKUP_DNS)..."
        B_RES=$(dig @"$BACKUP_DNS" +short "$DOMAIN" 2>/dev/null || true)
        if [ -n "$B_RES" ]; then
            echo "     Backup DNS is UP! Switch client DNS or bring primary dnsmasq back up."
        else
            echo "     DIAGNOSIS: Both DNS servers are down or unreachable!"
        fi
    fi
else
    echo " PASS: DNS resolved $DOMAIN -> $DNS_RES"
    EDGE_IP="$DNS_RES"
fi

# LAYER 2: NETWORK & TRANSPORT LAYER
echo ""
echo "[LAYER 2: NETWORK (IP) & TRANSPORT (TCP) REACHABILITY]"
echo "Checking Layer 3 ICMP reachability to Edge ($EDGE_IP)..."
if ping -c 1 -W 1000 "$EDGE_IP" >/dev/null 2>&1; then
    echo " PASS: ICMP Ping to $EDGE_IP succeeded."
else
    echo " WARNING: Ping to $EDGE_IP failed. (May be blocked or host down)."
fi

echo "Checking Layer 4 TCP Port $EDGE_PORT on $EDGE_IP..."
if nc -z -w 2 "$EDGE_IP" "$EDGE_PORT" 2>/dev/null; then
    echo " PASS: TCP port $EDGE_PORT is open and accepting SYN packets on $EDGE_IP."
else
    echo " FAIL: Cannot establish TCP connection to $EDGE_IP:$EDGE_PORT."
    echo " DIAGNOSIS: NGINX is not running on Mac 2 or wrong port is targeted!"
    exit 1
fi

# LAYER 3: TLS / SESSION LAYER
echo ""
echo "[LAYER 3: TLS HANDSHAKE & CERTIFICATE VALIDATION]"
echo "Testing TLS handshake on https://$DOMAIN:$EDGE_PORT..."

TLS_CHECK=$(echo | openssl s_client -connect "$EDGE_IP:$EDGE_PORT" -servername "$DOMAIN" 2>&1 || true)
if echo "$TLS_CHECK" | grep -q "Verify return code: 0 (ok)"; then
    echo " PASS: TLS Handshake succeeded and Certificate is verified & trusted!"
elif echo "$TLS_CHECK" | grep -q "verify error"; then
    echo " WARNING: TLS handshake succeeded, but CA / Certificate verification failed!"
    echo " DIAGNOSIS: Certificate not added to macOS Keychain trust store or expired."
else
    echo " TLS Error occurred during handshake."
fi

# LAYER 4: APPLICATION LAYER
echo ""
echo "[LAYER 4: APPLICATION & UPSTREAM REVERSE PROXY]"
echo "Sending HTTP request to https://$DOMAIN/..."

HTTP_RESPONSE=$(curl -s -i --connect-timeout 3 "https://$DOMAIN/" || true)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | grep "HTTP/" | head -1 | awk '{print $2}' || true)
BACKEND_TAG=$(echo "$HTTP_RESPONSE" | grep -i "X-Backend:" || true)

if [ "$HTTP_CODE" = "200" ]; then
    echo " PASS: HTTP 200 OK received! ($BACKEND_TAG)"
elif [ "$HTTP_CODE" = "502" ]; then
    echo " FAIL: HTTP 502 Bad Gateway!"
    echo " DIAGNOSIS: Edge NGINX is alive, but BOTH backends are unreachable or firewall is blocking NGINX!"
elif [ "$HTTP_CODE" = "504" ]; then
    echo " FAIL: HTTP 504 Gateway Timeout! Upstream backend hung or dropped connection."
else
    echo " Unexpected response: HTTP Code $HTTP_CODE"
fi

echo ""
echo "=================================================================="
echo "    DIAGNOSTIC COMPLETE — LAYER STATUS REPORTED"
echo "=================================================================="
