#!/usr/bin/env bash
# ==============================================================================
# update-ips.sh — Automatically synchronize IPs across all configs and scripts
# Run whenever you connect to a new Wi-Fi or router!
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ENV_FILE="$ROOT_DIR/config/network.env"

echo "=================================================================="
echo "         TEAM ADAM — NETWORK IP SYNCHRONIZATION UTILITY           "
echo "=================================================================="
echo ""

# Detect local IP
LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 'unknown')"
echo " Detected IP for this Mac ($(whoami)): $LOCAL_IP"
echo ""

# Source existing if present
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

CURRENT_M1="${MAC1_IP:-10.7.17.68}"
CURRENT_M2="${MAC2_IP:-10.7.21.52}"
CURRENT_M3="${MAC3_IP:-10.7.24.127}"
CURRENT_M4="${MAC4_IP:-10.7.13.20}"

if [ "${1:-}" != "--non-interactive" ]; then
    echo "Please enter the current LAN IP for each team member's Mac."
    echo "Press [ENTER] to keep the shown default value."
    echo ""
    read -r -p "Mac 1 — Manas  (Primary DNS)  [$CURRENT_M1]: " INPUT_M1
    read -r -p "Mac 2 — Anant  (Edge NGINX)   [$CURRENT_M2]: " INPUT_M2
    read -r -p "Mac 3 — Akhil  (Backend A)    [$CURRENT_M3]: " INPUT_M3
    read -r -p "Mac 4 — Darain (Backend B/DNS)[$CURRENT_M4]: " INPUT_M4

    NEW_M1="${INPUT_M1:-$CURRENT_M1}"
    NEW_M2="${INPUT_M2:-$CURRENT_M2}"
    NEW_M3="${INPUT_M3:-$CURRENT_M3}"
    NEW_M4="${INPUT_M4:-$CURRENT_M4}"
else
    NEW_M1="${2:-$CURRENT_M1}"
    NEW_M2="${3:-$CURRENT_M2}"
    NEW_M3="${4:-$CURRENT_M3}"
    NEW_M4="${5:-$CURRENT_M4}"
fi

echo ""
echo "Saving new IPs to $ENV_FILE:"
echo "  Mac 1 (Manas, DNS):    $NEW_M1"
echo "  Mac 2 (Anant, Edge):   $NEW_M2"
echo "  Mac 3 (Akhil, B-A):    $NEW_M3"
echo "  Mac 4 (Darain, B-B):   $NEW_M4"

cat <<EOF > "$ENV_FILE"
# Team Adam - Current Network IP Environment
# Updated on $(date)

MAC1_IP="$NEW_M1"   # Manas (Primary DNS)
MAC2_IP="$NEW_M2"   # Anant (Edge NGINX)
MAC3_IP="$NEW_M3"   # Akhil (Backend A)
MAC4_IP="$NEW_M4"   # Darain (Backend B & Backup DNS)

DOMAIN="app.team1.test"
API_DOMAIN="api.team1.test"
EOF

echo ""
echo "Updating configuration files..."

# 1. Update Primary dnsmasq
cat <<EOF > "$ROOT_DIR/config/dnsmasq/dnsmasq-phase2-primary.conf"
# Team Adam - Primary DNS (Mac 1: $NEW_M1)
address=/app.team1.test/$NEW_M2
address=/api.team1.test/$NEW_M2
local-ttl=30
listen-address=127.0.0.1,$NEW_M1
bind-interfaces
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=1.1.1.1
EOF

# 2. Update Backup dnsmasq
cat <<EOF > "$ROOT_DIR/config/dnsmasq/dnsmasq-phase2-backup.conf"
# Team Adam - Backup DNS (Mac 4: $NEW_M4)
address=/app.team1.test/$NEW_M2
address=/api.team1.test/$NEW_M2
local-ttl=30
listen-address=127.0.0.1,$NEW_M4
bind-interfaces
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=1.1.1.1
EOF

# 3. Update NGINX Phase 2
cat <<EOF > "$ROOT_DIR/config/nginx/nginx-phase2.conf"
worker_processes 1;
events { worker_connections 1024; }

http {
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;

    upstream backend_servers {
        server $NEW_M3:3001 max_fails=1 fail_timeout=5s;
        server $NEW_M4:3002 max_fails=1 fail_timeout=5s;
    }

    proxy_connect_timeout 1s;
    proxy_read_timeout 2s;
    proxy_next_upstream error timeout http_502 http_503;
    proxy_next_upstream_tries 2;

    server {
        listen 80;
        server_name app.team1.test api.team1.test;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name app.team1.test;

        ssl_certificate /opt/homebrew/etc/nginx/certs/app.team1.test.crt;
        ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.team1.test.key;
        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            add_header X-Edge-Proxy "nginx-primary-mac2" always;
        }
    }

    server {
        listen 443 ssl;
        server_name api.team1.test;

        ssl_certificate /opt/homebrew/etc/nginx/certs/team1.test.crt;
        ssl_certificate_key /opt/homebrew/etc/nginx/certs/team1.test.key;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# 4. Update NGINX Standby
cat <<EOF > "$ROOT_DIR/config/nginx/nginx-standby.conf"
worker_processes 1;
events { worker_connections 1024; }

http {
    default_type application/octet-stream;
    sendfile on;

    upstream backend_servers {
        server $NEW_M3:3001 max_fails=1 fail_timeout=5s;
        server $NEW_M4:3002 max_fails=1 fail_timeout=5s;
    }

    proxy_connect_timeout 1s;
    proxy_next_upstream error timeout http_502 http_503;

    server {
        listen 80;
        server_name app.team1.test;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name app.team1.test;

        ssl_certificate /opt/homebrew/etc/nginx/certs/app.team1.test.crt;
        ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.team1.test.key;

        location / {
            proxy_pass http://backend_servers;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            add_header X-Edge-Proxy "nginx-standby-mac3" always;
        }
    }
}
EOF

# 5. Update pf firewall rules
cat <<EOF > "$ROOT_DIR/config/firewall/pf-rules.conf"
# macOS pf configuration - Service Isolation
edge_ip = "$NEW_M2"
backend_ports = "{ 3001, 3002 }"

set skip on lo0

# Allow Edge IP
pass in quick proto tcp from \$edge_ip to any port \$backend_ports

# Block and reset all direct connections
block return-rst in quick proto tcp from any to any port \$backend_ports
EOF

echo ""
echo " All config files synchronized with the latest IP addresses!"

# Optional automatic git commit & push
if [ -d "$ROOT_DIR/.git" ]; then
    echo ""
    read -r -p "Would you like to automatically commit and push these changes to Git? (y/n) [y]: " PUSH_GIT
    PUSH_GIT="${PUSH_GIT:-y}"
    if [[ "$PUSH_GIT" =~ ^[Yy]$ ]]; then
        cd "$ROOT_DIR"
        git add config/
        git commit -m "chore: sync IP addresses for team ($NEW_M1, $NEW_M2, $NEW_M3, $NEW_M4)" || true
        echo "Pushing changes to Git repository..."
        if git push; then
            echo " Successfully pushed to Git!"
            echo " Now tell your 3 teammates to run: git pull"
        else
            echo " Push failed (maybe you need to pull or check credentials)."
            echo " You can push manually using: git push"
        fi
    fi
fi
