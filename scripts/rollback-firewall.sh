#!/usr/bin/env bash
# ==============================================================================
# rollback-firewall.sh — Disable pf Firewall & Restore Default Settings
# Run on Mac 3 (Akhil) and Mac 4 (Darain)
# ==============================================================================
set -euo pipefail

echo "=== Rolling back macOS pf Firewall Rules ==="
if [ "$EUID" -ne 0 ]; then
    echo "This script requires administrator privileges. Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "Flushing custom packet filter rules..."
pfctl -F all -f /etc/pf.conf 2>/dev/null || true

echo "Disabling pf..."
pfctl -d 2>/dev/null || true

echo " Firewall rules rolled back. Default networking restored."
