#!/usr/bin/env bash
# ==============================================================================
# apply-firewall.sh — Enforce Backend Service Isolation (macOS pf)
# Run on Mac 3 (Akhil) and Mac 4 (Darain)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PF_CONF="$SCRIPT_DIR/../config/firewall/pf-rules.conf"

echo "=== Applying macOS pf Firewall Rules for Service Isolation ==="
if [ "$EUID" -ne 0 ]; then
    echo "This script requires administrator privileges. Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [ ! -f "$PF_CONF" ]; then
    echo "Error: Firewall rules file not found at $PF_CONF" >&2
    exit 1
fi

echo "Testing syntax of $PF_CONF..."
pfctl -nf "$PF_CONF"

echo "Enabling pf and loading rules..."
pfctl -ef "$PF_CONF" 2>/dev/null || pfctl -f "$PF_CONF"

echo ""
echo " Active pf Rules for Service Isolation:"
pfctl -sr | grep -E "3001|3002" || true
echo ""
echo " Service isolation is ACTIVE."
echo " Direct access to ports 3001/3002 from unauthorized clients is now blocked."
echo " Authorized Edge (10.7.21.52) retains full access."
echo " To rollback, run: sudo ./scripts/rollback-firewall.sh"
