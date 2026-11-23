#!/usr/bin/env bash
# ==============================================================================
# test-backup-dns.sh — Test Phase 2 Extension A (Backup DNS Failover)
# Run from Client (Darain / Mac 4)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../config/network.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

PRIMARY_DNS="${MAC1_IP:-10.7.17.68}"
BACKUP_DNS="${MAC4_IP:-10.7.13.20}"
EDGE_IP="${MAC2_IP:-10.7.21.52}"
DOMAIN="${DOMAIN:-app.team1.test}"

echo "=========================================================="
echo "Phase 2 Extension A: Backup DNS Resolver Verification"
echo "=========================================================="
echo "Primary DNS: $PRIMARY_DNS | Backup DNS: $BACKUP_DNS"
echo ""

echo "Step 1: Testing Primary DNS Resolver ($PRIMARY_DNS)..."
if dig @"$PRIMARY_DNS" +short "$DOMAIN" | grep -q "$EDGE_IP"; then
    echo " Primary DNS resolved $DOMAIN -> $(dig @"$PRIMARY_DNS" +short "$DOMAIN")"
else
    echo " Primary DNS ($PRIMARY_DNS) failed or is unreachable."
fi
echo ""

echo "Step 2: Testing Backup DNS Resolver ($BACKUP_DNS)..."
if dig @"$BACKUP_DNS" +short "$DOMAIN" | grep -q "$EDGE_IP"; then
    echo " Backup DNS resolved $DOMAIN -> $(dig @"$BACKUP_DNS" +short "$DOMAIN")"
else
    echo " Backup DNS ($BACKUP_DNS) failed or is unreachable."
fi
echo ""

echo "Step 3: Checking System Resolver Configuration on this Mac..."
scutil --dns | grep 'nameserver\[[0-9]*\]' | head -4
echo ""

echo "Step 4: Automatic Failover Test"
echo "Now shut down dnsmasq on Mac 1 (Primary):"
echo "   Command on Mac 1: sudo brew services stop dnsmasq (or Ctrl+C)"
read -r -p "Press [Enter] after stopping Primary DNS on Mac 1 to test failover..."

echo "Resolving via system default DNS..."
RESOLVED_IP=$(dig +short "$DOMAIN" || true)
if [ -n "$RESOLVED_IP" ]; then
    echo " SUCCESS: Domain resolved to $RESOLVED_IP via Backup DNS ($BACKUP_DNS)!"
else
    echo " Failover failed. Ensure $BACKUP_DNS is listed in System Settings -> Network -> DNS."
fi
