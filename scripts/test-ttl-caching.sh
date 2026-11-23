#!/usr/bin/env bash
# ==============================================================================
# test-ttl-caching.sh — Interactive Phase 2 Extension B Demo
# Run from Client (Darain / Mac 4)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

PRIMARY_DNS="${MAC1_IP:-10.7.17.68}"
EDGE_IP="${MAC2_IP:-10.7.21.52}"
DOMAIN="${DOMAIN:-app.team1.test}"
DUMMY_IP="10.7.21.99"

echo "=================================================================="
echo "    PHASE 2 EXTENSION B: DNS TTL & CACHE INVALIDATION DEMO        "
echo "=================================================================="
echo "Domain:      $DOMAIN"
echo "Primary DNS: $PRIMARY_DNS"
echo "Edge IP:     $EDGE_IP"
echo "Dummy IP:    $DUMMY_IP (used for cutover demonstration)"
echo "------------------------------------------------------------------"

echo ""
echo "--- STEP 1: Verify Current DNS Resolution & 30-Second TTL ---"
echo "Querying Primary DNS ($PRIMARY_DNS)..."
DNS_OUT=$(dig @"$PRIMARY_DNS" "$DOMAIN" | grep -A 1 "ANSWER SECTION:" | tail -1)
echo "  DNS Record: $DNS_OUT"
TTL_VAL=$(echo "$DNS_OUT" | awk '{print $2}')
echo "  -> Notice the TTL value: ${TTL_VAL} seconds!"
echo "  -> This tells clients to cache this IP for $TTL_VAL seconds before asking again."
echo ""

# Prime local macOS resolver cache
echo "Priming local macOS cache by resolving $DOMAIN..."
LOCAL_RESOLVED=$(dscacheutil -q host -a name "$DOMAIN" | grep "ip_address:" | head -1 | awk '{print $2}' || dig +short "$DOMAIN" || true)
echo "  macOS Cache currently returns: $LOCAL_RESOLVED"
echo ""

echo "------------------------------------------------------------------"
echo "--- STEP 2: Manas Changes the DNS Record on Mac 1 ---"
echo "Now ask Manas on Mac 1 to do the following:"
echo "  1. Open: config/dnsmasq/dnsmasq-phase2-primary.conf"
echo "  2. Change: address=/$DOMAIN/$EDGE_IP"
echo "         to: address=/$DOMAIN/$DUMMY_IP"
echo "  3. Reload dnsmasq: sudo killall -HUP dnsmasq"
echo "------------------------------------------------------------------"
read -r -p "Press [ENTER] after Manas has changed the record and reloaded dnsmasq..."

echo ""
echo "--- STEP 3: Observe Client DNS Caching Behavior ---"
echo "Checking what the DNS Server ($PRIMARY_DNS) is now serving:"
SERVER_NOW=$(dig @"$PRIMARY_DNS" +short "$DOMAIN" || true)
echo "  Direct from DNS Server: $SERVER_NOW  <-- DNS server already has the NEW IP!"
echo ""

echo "Checking what your Mac's Operating System resolver returns:"
LOCAL_NOW=$(dscacheutil -q host -a name "$DOMAIN" | grep "ip_address:" | head -1 | awk '{print $2}' || true)
if [ -z "$LOCAL_NOW" ]; then
    LOCAL_NOW=$(dig +short "$DOMAIN" || echo "unknown")
fi
echo "  Local macOS Cache returns: $LOCAL_NOW"
echo ""

if [ "$LOCAL_NOW" = "$EDGE_IP" ]; then
    echo "  EVIDENCE OF CACHING:"
    echo "    Even though the DNS server changed to $DUMMY_IP, your Mac STILL"
    echo "    returns the old IP ($EDGE_IP) because the 30-second TTL hasn't expired!"
    echo "    In production, this is why clients don't see instant DNS changes."
else
    echo "  Note: Cache already expired or was bypassed."
fi
echo ""

echo "------------------------------------------------------------------"
echo "--- STEP 4: Manual Cache Invalidation (Flush DNS Cache) ---"
echo "In production migrations, we flush cache to force immediate cutover."
echo "Command to run: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
echo "------------------------------------------------------------------"
read -r -p "Press [ENTER] to flush your Mac's DNS cache now..."

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "  Local DNS cache flushed!"
echo ""

echo "--- STEP 5: Verify Immediate Cutover After Flush ---"
FLUSHED_RESOLVED=$(dscacheutil -q host -a name "$DOMAIN" | grep "ip_address:" | head -1 | awk '{print $2}' || dig +short "$DOMAIN" || true)
echo "  Local macOS Resolver now returns: $FLUSHED_RESOLVED"

if [ "$FLUSHED_RESOLVED" = "$DUMMY_IP" ]; then
    echo ""
    echo "  SUCCESS: The Mac immediately picked up the new IP ($DUMMY_IP)!"
    echo "  This proves: 1. TTL caching holds old records in client memory."
    echo "               2. Flushing forces immediate re-query."
fi

echo ""
echo "------------------------------------------------------------------"
echo "--- CLEANUP: Restore Original Settings ---"
echo "Ask Manas on Mac 1 to restore the original Edge IP ($EDGE_IP) in"
echo "config/dnsmasq/dnsmasq-phase2-primary.conf and run: sudo killall -HUP dnsmasq"
echo "Then flush your cache once more."
echo "=================================================================="
