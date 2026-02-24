#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Traffic Checker — AlmaLinux 8 + WHM/cPanel Setup
# Run as ROOT via SSH or WHM Terminal
# Safe for shared hosting servers with multiple client sites
# ════════════════════════════════════════════════════════════════

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Traffic Checker — AlmaLinux 8 + WHM/cPanel Setup       ║"
echo "║  Safe for shared servers with multiple client sites      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Verify we're on AlmaLinux / RHEL 8 ───────────────────────
if ! grep -qi "almalinux\|centos.*8\|rhel.*8\|rocky" /etc/os-release 2>/dev/null; then
    warn "This script is for AlmaLinux 8 / CentOS 8. Proceeding anyway..."
fi

if [ "$EUID" -ne 0 ]; then
    err "Please run as root: sudo bash almalinux_setup.sh"
    exit 1
fi

# ── 1. Enable required repos ──────────────────────────────────
echo "[1/7] Enabling package repositories..."
dnf install -y epel-release 2>/dev/null || true
dnf config-manager --set-enabled powertools 2>/dev/null || \
dnf config-manager --set-enabled crb 2>/dev/null || true
ok "Repositories enabled"

# ── 2. Chromium system libraries ─────────────────────────────
echo ""
echo "[2/7] Installing Chromium system libraries..."
dnf install -y \
    xorg-x11-server-Xvfb \
    nss \
    atk \
    at-spi2-atk \
    cups-libs \
    libdrm \
    libXcomposite \
    libXdamage \
    libXfixes \
    libXrandr \
    mesa-libgbm \
    libxkbcommon \
    pango \
    cairo \
    alsa-lib \
    gtk3 \
    libXScrnSaver \
    libXtst \
    xdg-utils \
    2>/dev/null
ok "Chromium libraries installed"

# ── 3. Python 3 + pip ─────────────────────────────────────────
echo ""
echo "[3/7] Setting up Python 3..."
dnf install -y python3 python3-pip 2>/dev/null
PY_VERSION=$(python3 --version)
ok "Python: $PY_VERSION"
pip3 install --upgrade pip -q
ok "pip upgraded"

# ── 4. Node.js 20 (for playwright install command) ───────────
echo ""
echo "[4/7] Installing Node.js 20..."
if ! command -v node &>/dev/null || [[ "$(node -v)" < "v18" ]]; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - 2>/dev/null
    dnf install -y nodejs 2>/dev/null
fi
ok "Node: $(node -v)"

# ── 5. Playwright + Chromium ─────────────────────────────────
echo ""
echo "[5/7] Installing Playwright and Chromium browser..."
echo "      (Downloads ~200MB — takes 2-3 minutes)"
pip3 install playwright -q
ok "Playwright Python library installed"

# Install Chromium and all its dependencies
python3 -m playwright install chromium
python3 -m playwright install-deps chromium 2>/dev/null || \
    warn "playwright install-deps failed — libraries were installed manually above"

# Find and record Chromium binary path
CHROMIUM_PATH=$(find /root/.cache/ms-playwright -name 'chrome' -type f 2>/dev/null | head -1)
if [ -z "$CHROMIUM_PATH" ]; then
    CHROMIUM_PATH=$(find ~/.cache/ms-playwright -name 'chrome' -type f 2>/dev/null | head -1)
fi

if [ -n "$CHROMIUM_PATH" ]; then
    ok "Chromium binary: $CHROMIUM_PATH"
else
    warn "Chromium path not found — may install to a different location"
fi

# Quick smoke test
echo "      Testing Chromium..."
python3 -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage'])
    b.close()
print('      Chromium OK')
" && ok "Chromium smoke test passed" || warn "Chromium test failed — check DISPLAY setting"

# ── 6. Xvfb virtual display ───────────────────────────────────
echo ""
echo "[6/7] Setting up Xvfb virtual display (needed by Chromium)..."

# Create systemd service
cat > /etc/systemd/system/xvfb-traffic.service << 'SERVICE'
[Unit]
Description=Xvfb Virtual Display for Traffic Checker Chromium
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX
ExecStartPost=/bin/sleep 1
Restart=on-failure
RestartSec=5
# Run as nobody — safe on shared servers, no access to client files
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable xvfb-traffic
systemctl start xvfb-traffic
sleep 2

if systemctl is-active --quiet xvfb-traffic; then
    ok "Xvfb running on display :99 (service: xvfb-traffic)"
else
    warn "Xvfb service failed to start — trying direct launch..."
    /usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac &
    sleep 1
    # Add to crontab as fallback
    (crontab -l 2>/dev/null; echo "@reboot /usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac &") | sort -u | crontab -
    ok "Xvfb started directly (added @reboot cron as backup)"
fi

# ── 7. Detect cPanel PHP versions ────────────────────────────
echo ""
echo "[7/7] Detecting available cPanel PHP versions..."
BEST_PHP=""
for ver in ea-php83 ea-php82 ea-php81 ea-php80; do
    BIN="/opt/cpanel/$ver/root/usr/bin/php"
    if [ -x "$BIN" ]; then
        VER=$($BIN -r 'echo PHP_VERSION;')
        ok "Found: $BIN ($VER)"
        [ -z "$BEST_PHP" ] && BEST_PHP="$BIN"
    fi
done

if [ -z "$BEST_PHP" ]; then
    BEST_PHP=$(which php 2>/dev/null || echo "/usr/bin/php")
    warn "No cPanel PHP found — using: $BEST_PHP"
fi

# Check required PHP extensions
echo ""
echo "      Checking PHP extensions for: $BEST_PHP"
for ext in pdo_mysql mbstring xml curl zip bcmath json; do
    if $BEST_PHP -m 2>/dev/null | grep -q "^$ext$"; then
        echo -e "      ${GREEN}✓${NC} $ext"
    else
        echo -e "      ${RED}✗${NC} $ext — install in WHM → EasyApache 4"
    fi
done

# Check Composer
echo ""
if ! command -v composer &>/dev/null; then
    echo "      Installing Composer..."
    curl -sS https://getcomposer.org/installer | $BEST_PHP -- --install-dir=/usr/local/bin --filename=composer
    ok "Composer installed"
else
    ok "Composer: $(composer --version 2>/dev/null | head -1)"
fi

# ── Save config for deploy script ────────────────────────────
cat > /root/.traffic-checker-config << CONF
BEST_PHP=$BEST_PHP
DISPLAY=:99
SETUP_DATE=$(date)
CONF

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  System setup complete!                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Recommended PHP: $BEST_PHP"
echo "║  Xvfb display:    :99                                        ║"
echo "║                                                              ║"
echo "║  NEXT STEP — run the deploy script:                          ║"
echo "║    bash cpanel_deploy.sh yourdomain.com cpanel_username      ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
