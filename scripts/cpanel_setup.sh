#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Traffic Checker — WHM/cPanel Server Setup
# Run as root via SSH terminal
# Tested on: AlmaLinux 8, CentOS 7, Ubuntu 22.04 with cPanel
# ════════════════════════════════════════════════════════════════

set -e

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Traffic Checker — WHM/cPanel Setup            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Detect OS ────────────────────────────────────────────────
if [ -f /etc/almalinux-release ]; then
    OS="almalinux"
    PKG="dnf"
elif [ -f /etc/centos-release ]; then
    OS="centos"
    PKG="yum"
elif [ -f /etc/ubuntu-version ] || grep -qi ubuntu /etc/os-release 2>/dev/null; then
    OS="ubuntu"
    PKG="apt-get"
else
    OS="unknown"
    PKG="yum"
fi
echo "  Detected OS: $OS"

# ── 1. Install system libraries for Chromium ─────────────────
echo ""
echo "[1/6] Installing Chromium system dependencies..."

if [ "$OS" = "ubuntu" ]; then
    apt-get update -q
    apt-get install -y -q \
        xvfb libnss3 libatk1.0-0 libatk-bridge2.0-0 \
        libcups2 libdrm2 libxcomposite1 libxdamage1 \
        libxfixes3 libxrandr2 libgbm1 libxkbcommon0 \
        libpango-1.0-0 libcairo2 libasound2 \
        python3 python3-pip git unzip
else
    # RHEL/CentOS/AlmaLinux/CloudLinux
    $PKG install -y \
        xorg-x11-server-Xvfb nss atk at-spi2-atk \
        cups-libs libdrm libXcomposite libXdamage \
        libXfixes libXrandr mesa-libgbm libxkbcommon \
        pango cairo alsa-lib \
        python3 python3-pip git unzip 2>/dev/null || \
    $PKG install -y \
        Xvfb nss atk at-spi2-atk \
        cups-libs libdrm libXcomposite libXdamage \
        libXfixes libXrandr mesa-libgbm libxkbcommon \
        pango cairo alsa-lib \
        python3 python3-pip git unzip
fi
echo "  ✓ System libraries installed"

# ── 2. Install Node.js (for Playwright install command) ───────
echo ""
echo "[2/6] Installing Node.js..."
if ! command -v node &>/dev/null; then
    if [ "$OS" = "ubuntu" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    else
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        $PKG install -y nodejs
    fi
fi
echo "  ✓ Node $(node -v) ready"

# ── 3. Install Python + Playwright ───────────────────────────
echo ""
echo "[3/6] Installing Python Playwright + Chromium..."
pip3 install --upgrade pip -q
pip3 install playwright -q
python3 -m playwright install chromium
python3 -m playwright install-deps chromium 2>/dev/null || true
echo "  ✓ Playwright + Chromium installed"

# Locate chromium binary path
CHROMIUM_PATH=$(python3 -c "
import subprocess, sys
result = subprocess.run(['python3', '-m', 'playwright', 'show-browser', 'chromium'], 
    capture_output=True, text=True)
" 2>/dev/null || true)

# Find it manually
CHROMIUM_BIN=$(find /root/.cache/ms-playwright -name 'chrome' -o -name 'chromium' 2>/dev/null | head -1)
echo "  Chromium binary: ${CHROMIUM_BIN:-not found yet}"

# ── 4. Xvfb virtual display service ──────────────────────────
echo ""
echo "[4/6] Setting up Xvfb virtual display..."

# Check if systemd is available (may not be in some cPanel containers)
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null; then
    cat > /etc/systemd/system/xvfb.service << 'SERVICE'
[Unit]
Description=Xvfb Virtual Display for Chromium
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl enable xvfb --now
    echo "  ✓ Xvfb running via systemd on :99"
else
    # Fallback: start Xvfb in background via cron @reboot
    XVFB_CMD="/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac"
    $XVFB_CMD &
    # Add to crontab to start on boot
    (crontab -l 2>/dev/null; echo "@reboot $XVFB_CMD &") | sort -u | crontab -
    echo "  ✓ Xvfb started (fallback mode, added to @reboot cron)"
fi

# ── 5. Install Composer (if not present) ─────────────────────
echo ""
echo "[5/6] Checking Composer..."
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "  ✓ Composer installed"
else
    echo "  ✓ Composer already present: $(composer --version 2>/dev/null | head -1)"
fi

# ── 6. Detect cPanel PHP path ─────────────────────────────────
echo ""
echo "[6/6] Detecting cPanel PHP installations..."
echo ""
echo "  Available PHP versions:"
ls /opt/cpanel/ 2>/dev/null | grep "^ea-php" | while read ver; do
    BIN="/opt/cpanel/$ver/root/usr/bin/php"
    if [ -x "$BIN" ]; then
        echo "    $BIN ($($BIN -r 'echo PHP_VERSION;'))"
    fi
done

# Recommend PHP 8.2 or 8.3
RECOMMENDED_PHP=$(ls /opt/cpanel/ 2>/dev/null | grep -E "^ea-php8[23]" | sort -r | head -1)
if [ -n "$RECOMMENDED_PHP" ]; then
    PHP_BIN="/opt/cpanel/$RECOMMENDED_PHP/root/usr/bin/php"
    echo ""
    echo "  ★ Recommended: $PHP_BIN"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  System setup complete!                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  NEXT: Run the deploy script for your specific domain:       ║"
echo "║    bash cpanel_deploy.sh yourdomain.com                      ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
