#!/bin/bash
# ============================================================
# Tom Spark's ARR Stack — Health Check & Troubleshooting
# https://github.com/loponai/arrstack
#
# Run this after 'docker compose up -d' to verify everything
# is working correctly. It checks each service, tests VPN
# connectivity, and provides specific fixes for any issues.
#
# Usage: bash test-stack.sh
# ============================================================

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS="${GREEN}✓ PASS${NC}"
FAIL="${RED}✗ FAIL${NC}"
WARN="${YELLOW}! WARN${NC}"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

pass() { echo -e "  ${PASS}  $1"; ((TOTAL_PASS++)); }
fail() { echo -e "  ${FAIL}  $1"; ((TOTAL_FAIL++)); }
warn() { echo -e "  ${WARN}  $1"; ((TOTAL_WARN++)); }
header() { echo -e "\n${CYAN}${BOLD}[$1]${NC}"; }
fix() { echo -e "         ${YELLOW}Fix: $1${NC}"; }

echo ""
echo "========================================="
echo "  Tom Spark's ARR Stack — Health Check"
echo "========================================="
echo ""

# ============================================================
# TEST 1: Docker running?
# ============================================================
header "Docker"

if docker info > /dev/null 2>&1; then
    pass "Docker is running"
else
    fail "Docker is not running"
    fix "Start Docker: sudo systemctl start docker"
    fix "Or install: curl -fsSL https://get.docker.com | sh"
    echo ""
    echo "Cannot continue without Docker. Exiting."
    exit 1
fi

# ============================================================
# TEST 2: .env file exists and has VPN credentials?
# ============================================================
header "Configuration"

if [ -f .env ]; then
    pass ".env file exists"
else
    fail ".env file not found"
    fix "Run: cp .env.example .env && nano .env"
    fix "Then fill in your VPN credentials"
fi

if [ -f .env ]; then
    VPN_KEY=$(grep -E "^WIREGUARD_PRIVATE_KEY=" .env 2>/dev/null | cut -d= -f2)
    VPN_PROVIDER=$(grep -E "^VPN_SERVICE_PROVIDER=" .env 2>/dev/null | cut -d= -f2)

    if [ -n "$VPN_KEY" ] && [ "$VPN_KEY" != "" ]; then
        pass "VPN private key is set (provider: $VPN_PROVIDER)"
    else
        fail "VPN private key is empty"
        fix "Edit .env and paste your WireGuard private key"
        fix "Get it from your VPN provider's manual setup page"
    fi
fi

# ============================================================
# TEST 3: Folder structure exists?
# ============================================================
header "Folder Structure"

ALL_FOLDERS_OK=true
for dir in /data/torrents/movies /data/torrents/tv /data/torrents/music /data/media/movies /data/media/tv /data/media/music; do
    if [ -d "$dir" ]; then
        pass "$dir exists"
    else
        fail "$dir missing"
        ALL_FOLDERS_OK=false
    fi
done

if [ "$ALL_FOLDERS_OK" = false ]; then
    fix "Run: sudo bash setup-folders.sh"
fi

# Check permissions
if [ -d /data ]; then
    OWNER=$(stat -c '%u' /data 2>/dev/null)
    ENV_PUID=$(grep -E "^PUID=" .env 2>/dev/null | cut -d= -f2)
    if [ "$OWNER" = "$ENV_PUID" ] || [ "$OWNER" = "$(id -u)" ]; then
        pass "/data ownership matches PUID ($OWNER)"
    else
        warn "/data owned by $OWNER but PUID is ${ENV_PUID:-1000}"
        fix "Run: sudo chown -R ${ENV_PUID:-1000}:${ENV_PUID:-1000} /data"
    fi
fi

# ============================================================
# TEST 4: Container status
# ============================================================
header "Containers"

EXPECTED_SERVICES="gluetun qbittorrent deunhealth prowlarr flaresolverr radarr sonarr lidarr bazarr jellyfin seerr"

for svc in $EXPECTED_SERVICES; do
    STATUS=$(docker inspect --format '{{.State.Status}}' "$svc" 2>/dev/null)
    HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$svc" 2>/dev/null)

    if [ -z "$STATUS" ]; then
        fail "$svc — not found (not created)"
        fix "Run: docker compose up -d"
    elif [ "$STATUS" = "running" ]; then
        if [ "$HEALTH" = "healthy" ]; then
            pass "$svc — running (healthy)"
        elif [ "$HEALTH" = "unhealthy" ]; then
            fail "$svc — running but UNHEALTHY"
            if [ "$svc" = "gluetun" ]; then
                fix "VPN probably can't connect. Check credentials in .env"
                fix "Check logs: docker logs gluetun | tail -20"
                fix "Try: rm -rf gluetun && docker compose up -d gluetun"
            elif [ "$svc" = "qbittorrent" ]; then
                fix "Usually means VPN dropped. Deunhealth should auto-restart it."
                fix "Check: docker logs qbittorrent | tail -20"
            fi
        elif [ "$HEALTH" = "starting" ]; then
            warn "$svc — running (health check starting, wait 30s and rerun)"
        else
            pass "$svc — running"
        fi
    elif [ "$STATUS" = "created" ]; then
        warn "$svc — created but not started"
        if [ "$svc" = "qbittorrent" ] || [ "$svc" = "prowlarr" ] || [ "$svc" = "flaresolverr" ]; then
            fix "Waiting for Gluetun to be healthy. Check Gluetun status first."
            fix "If Gluetun is healthy, try: docker compose up -d $svc"
        elif [ "$svc" = "seerr" ]; then
            fix "Port 5055 may be in use. Check: ss -tlnp | grep 5055"
            fix "Or change the port in docker-compose.yml"
        else
            fix "Try: docker compose up -d $svc"
        fi
    elif [ "$STATUS" = "exited" ]; then
        fail "$svc — exited (crashed)"
        fix "Check logs: docker logs $svc | tail -30"
        fix "Try restarting: docker compose up -d $svc"
    else
        warn "$svc — status: $STATUS"
    fi
done

# ============================================================
# TEST 5: VPN connectivity
# ============================================================
header "VPN Connection"

GLUETUN_STATUS=$(docker inspect --format '{{.State.Status}}' gluetun 2>/dev/null)
GLUETUN_HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' gluetun 2>/dev/null)

if [ "$GLUETUN_STATUS" = "running" ] && [ "$GLUETUN_HEALTH" = "healthy" ]; then
    # Get VPN IP
    VPN_IP=$(docker exec gluetun wget -qO- --timeout=10 ipinfo.io/ip 2>/dev/null)
    if [ -n "$VPN_IP" ]; then
        pass "Gluetun VPN IP: $VPN_IP"

        # Get VPN location
        VPN_LOCATION=$(docker exec gluetun wget -qO- --timeout=10 "ipinfo.io/${VPN_IP}/city" 2>/dev/null)
        VPN_COUNTRY=$(docker exec gluetun wget -qO- --timeout=10 "ipinfo.io/${VPN_IP}/country" 2>/dev/null)
        if [ -n "$VPN_LOCATION" ]; then
            pass "VPN location: $VPN_LOCATION, $VPN_COUNTRY"
        fi
    else
        fail "Gluetun is healthy but can't reach the internet"
        fix "Check logs: docker logs gluetun | tail -20"
    fi

    # Check if qBittorrent is tunneled
    QBIT_STATUS=$(docker inspect --format '{{.State.Status}}' qbittorrent 2>/dev/null)
    if [ "$QBIT_STATUS" = "running" ]; then
        QBIT_IP=$(docker exec qbittorrent wget -qO- --timeout=10 ipinfo.io/ip 2>/dev/null)
        if [ "$QBIT_IP" = "$VPN_IP" ]; then
            pass "qBittorrent tunneled through VPN ($QBIT_IP)"
        elif [ -n "$QBIT_IP" ]; then
            fail "qBittorrent IP ($QBIT_IP) doesn't match VPN IP ($VPN_IP)!"
            fix "This should not happen. Check network_mode in docker-compose.yml"
        else
            warn "Could not check qBittorrent IP (container may still be starting)"
        fi
    fi

    # Check if Prowlarr is tunneled
    PROWLARR_STATUS=$(docker inspect --format '{{.State.Status}}' prowlarr 2>/dev/null)
    if [ "$PROWLARR_STATUS" = "running" ]; then
        PROWLARR_IP=$(docker exec prowlarr wget -qO- --timeout=10 ipinfo.io/ip 2>/dev/null)
        if [ "$PROWLARR_IP" = "$VPN_IP" ]; then
            pass "Prowlarr tunneled through VPN ($PROWLARR_IP)"
        elif [ -n "$PROWLARR_IP" ]; then
            fail "Prowlarr IP ($PROWLARR_IP) doesn't match VPN IP ($VPN_IP)!"
        fi
    fi

    # Verify your real IP is different
    REAL_IP=$(wget -qO- --timeout=10 ipinfo.io/ip 2>/dev/null)
    if [ -n "$REAL_IP" ] && [ "$REAL_IP" != "$VPN_IP" ]; then
        pass "Real IP ($REAL_IP) differs from VPN IP — VPN is working!"
    elif [ "$REAL_IP" = "$VPN_IP" ]; then
        warn "Real IP matches VPN IP — are you already running a system-wide VPN?"
    fi
else
    if [ "$GLUETUN_HEALTH" = "unhealthy" ]; then
        fail "Gluetun is unhealthy — VPN not connected"
        fix "Check credentials in .env (these are NOT your VPN login email/password)"
        fix "Check logs: docker logs gluetun 2>&1 | tail -30"
        fix "Try resetting: docker compose down && rm -rf gluetun && docker compose up -d"
    elif [ "$GLUETUN_HEALTH" = "starting" ]; then
        warn "Gluetun health check still starting — wait 30-60 seconds and rerun"
    else
        warn "Gluetun not running — can't test VPN"
        fix "Run: docker compose up -d"
    fi
fi

# ============================================================
# TEST 6: Service web UI accessibility
# ============================================================
header "Web UI Access"

check_http() {
    local name=$1 port=$2
    local code=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$port" 2>/dev/null)
    if [ "$code" = "200" ] || [ "$code" = "302" ] || [ "$code" = "301" ] || [ "$code" = "307" ]; then
        pass "$name — http://localhost:$port (HTTP $code)"
    elif [ "$code" = "000" ]; then
        # Container might be behind gluetun, check if it's running
        local status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
        if [ "$status" = "running" ]; then
            warn "$name — container running but port $port not reachable from host"
            fix "Port may be mapped on Gluetun. Try: http://localhost:$port"
        else
            fail "$name — not reachable (container not running)"
        fi
    else
        warn "$name — http://localhost:$port returned HTTP $code"
    fi
}

check_http qbittorrent 8080
check_http prowlarr 9696
check_http radarr 7878
check_http sonarr 8989
check_http lidarr 8686
check_http bazarr 6767
check_http jellyfin 8096
check_http seerr 5055

# ============================================================
# TEST 7: Hard link capability
# ============================================================
header "Hard Links"

if [ -d /data/torrents ] && [ -d /data/media ]; then
    # Check if same filesystem
    FS_TORRENTS=$(df /data/torrents --output=source 2>/dev/null | tail -1)
    FS_MEDIA=$(df /data/media --output=source 2>/dev/null | tail -1)

    if [ "$FS_TORRENTS" = "$FS_MEDIA" ]; then
        pass "torrents/ and media/ are on the same filesystem ($FS_TORRENTS)"
        pass "Hard links will work correctly"
    else
        fail "torrents/ ($FS_TORRENTS) and media/ ($FS_MEDIA) are on DIFFERENT filesystems!"
        fix "Hard links only work on the same filesystem/drive"
        fix "Move both directories to the same drive"
    fi

    # Quick hard link test
    TEST_FILE="/data/torrents/.hardlink_test_$$"
    TEST_LINK="/data/media/.hardlink_test_$$"
    if touch "$TEST_FILE" 2>/dev/null && ln "$TEST_FILE" "$TEST_LINK" 2>/dev/null; then
        pass "Hard link test succeeded"
        rm -f "$TEST_FILE" "$TEST_LINK" 2>/dev/null
    elif [ -f "$TEST_FILE" ]; then
        fail "Hard link test failed — filesystem may not support hard links"
        fix "Check filesystem type: df -T /data"
        fix "Hard links work on ext4, btrfs, xfs. NOT on exFAT or ntfs-3g"
        rm -f "$TEST_FILE" 2>/dev/null
    else
        warn "Could not write to /data/torrents (permission issue?)"
        fix "Run: sudo chown -R $(id -u):$(id -g) /data"
    fi
else
    warn "Folder structure not found — skipping hard link test"
    fix "Run: sudo bash setup-folders.sh"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================="
echo -e "  ${GREEN}Passed: $TOTAL_PASS${NC}   ${RED}Failed: $TOTAL_FAIL${NC}   ${YELLOW}Warnings: $TOTAL_WARN${NC}"
echo "========================================="

if [ $TOTAL_FAIL -eq 0 ] && [ $TOTAL_WARN -eq 0 ]; then
    echo -e "\n  ${GREEN}${BOLD}All checks passed! Your stack is ready to go.${NC}\n"
elif [ $TOTAL_FAIL -eq 0 ]; then
    echo -e "\n  ${YELLOW}${BOLD}No failures, but check the warnings above.${NC}\n"
else
    echo -e "\n  ${RED}${BOLD}Some checks failed. Follow the fix instructions above.${NC}"
    echo -e "  ${BOLD}If stuck, check: docker logs <container-name>${NC}\n"
fi
