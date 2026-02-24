#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Traffic Checker — cPanel Domain Deploy
# Usage: bash cpanel_deploy.sh yourdomain.com cpanel_username
# Run AFTER almalinux_setup.sh
# ════════════════════════════════════════════════════════════════

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }

DOMAIN="${1:?Usage: bash cpanel_deploy.sh domain.com cpanel_username}"
CPANEL_USER="${2:?Usage: bash cpanel_deploy.sh domain.com cpanel_username}"

USER_HOME="/home/$CPANEL_USER"
APP_DIR="$USER_HOME/traffic-checker"        # Laravel app (outside public_html)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load saved config from setup script
[ -f /root/.traffic-checker-config ] && source /root/.traffic-checker-config

# Auto-detect best PHP if not loaded
if [ -z "$BEST_PHP" ]; then
    for ver in ea-php83 ea-php82 ea-php81; do
        BIN="/opt/cpanel/$ver/root/usr/bin/php"
        [ -x "$BIN" ] && BEST_PHP="$BIN" && break
    done
    BEST_PHP="${BEST_PHP:-$(which php)}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Traffic Checker — cPanel Deploy                        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Domain  : $DOMAIN"
echo "║  User    : $CPANEL_USER"
echo "║  PHP     : $BEST_PHP"
echo "║  App dir : $APP_DIR"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Validate user exists ──────────────────────────────────────
id "$CPANEL_USER" &>/dev/null || err "cPanel user '$CPANEL_USER' not found"

# ── 1. Copy application files ─────────────────────────────────
echo "[1/8] Copying application files..."
mkdir -p "$APP_DIR"

# Copy from extracted zip location
if [ -d "$SCRIPT_DIR/traffic-checker" ]; then
    rsync -a --exclude='vendor' --exclude='node_modules' \
        "$SCRIPT_DIR/traffic-checker/" "$APP_DIR/"
    ok "App files copied to $APP_DIR"
elif [ -d "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/composer.json" ]; then
    # Script is already inside the project
    rsync -a --exclude='vendor' --exclude='node_modules' \
        "$SCRIPT_DIR/" "$APP_DIR/"
    ok "App files copied to $APP_DIR"
else
    warn "Could not auto-copy files. Upload manually to $APP_DIR"
fi

# Copy Python scripts
for f in traffic_checker.py; do
    for src in "$SCRIPT_DIR/$f" "$SCRIPT_DIR/../$f" "/root/$f"; do
        if [ -f "$src" ]; then
            cp "$src" "$USER_HOME/$f"
            ok "Copied $f to $USER_HOME/"
            break
        fi
    done
done

# ── 2. MySQL database ─────────────────────────────────────────
echo ""
echo "[2/8] Creating MySQL database..."

# Sanitize names (cPanel max 8 chars for prefix)
PREFIX=$(echo "$CPANEL_USER" | cut -c1-8 | tr -cd 'a-zA-Z0-9')
DB_NAME="${PREFIX}_traff"
DB_USER="${PREFIX}_trafusr"
DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)

# Try cPanel API first (preferred — registers DB with cPanel)
if command -v uapi &>/dev/null; then
    uapi --user="$CPANEL_USER" Mysql create_database name="${DB_NAME}" 2>/dev/null && \
        ok "Database '$DB_NAME' created via cPanel API" || warn "DB may already exist"
    uapi --user="$CPANEL_USER" Mysql create_user name="${DB_USER}" password="${DB_PASS}" 2>/dev/null && \
        ok "DB user '$DB_USER' created" || warn "User may already exist"
    uapi --user="$CPANEL_USER" Mysql set_privileges_on_database \
        user="${DB_USER}" database="${DB_NAME}" privileges="ALL PRIVILEGES" 2>/dev/null && \
        ok "Privileges granted" || warn "Could not set privileges via API"
    # Also add full DB name prefix
    FULL_DB="${CPANEL_USER}_traff"
    FULL_USER="${CPANEL_USER}_trafusr"
    DB_NAME="$FULL_DB"
    DB_USER="$FULL_USER"
else
    # Direct MySQL root access
    mysql -u root 2>/dev/null << SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
    ok "Database and user created via MySQL root"
fi

echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  DATABASE CREDENTIALS — SAVE THESE!     │"
echo "  │  DB Name : $DB_NAME"
echo "  │  DB User : $DB_USER"
echo "  │  DB Pass : $DB_PASS"
echo "  └─────────────────────────────────────────┘"

# ── 3. Create .env ────────────────────────────────────────────
echo ""
echo "[3/8] Creating .env configuration..."

# Detect cPanel mail settings
MAIL_HOST="mail.$DOMAIN"

cat > "$APP_DIR/.env" << ENV
APP_NAME="Traffic Checker"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://${DOMAIN}
APP_TIMEZONE=Africa/Cairo

LOG_CHANNEL=stack
LOG_LEVEL=error

# ── Database ─────────────────────────────────────────────────
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

# ── Cache/Session (file driver — no Redis needed on cPanel) ──
CACHE_DRIVER=file
SESSION_DRIVER=file
SESSION_LIFETIME=120
QUEUE_CONNECTION=sync

# ── Mail (your cPanel email account) ─────────────────────────
MAIL_MAILER=smtp
MAIL_HOST=${MAIL_HOST}
MAIL_PORT=587
MAIL_USERNAME=alerts@${DOMAIN}
MAIL_PASSWORD=YOUR_EMAIL_PASSWORD_HERE
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=alerts@${DOMAIN}
MAIL_FROM_NAME="Traffic Violations Alert"

# ── WhatsApp — Green API (free 2000/month) ────────────────────
# Register at https://green-api.com → Create Instance → Scan QR
WHATSAPP_PROVIDER=green_api
WHATSAPP_INSTANCE_ID=YOUR_INSTANCE_ID
WHATSAPP_ACCESS_TOKEN=YOUR_ACCESS_TOKEN

# ── Python / Playwright ───────────────────────────────────────
PYTHON_BIN=/usr/bin/python3
PYTHON_SCRIPT_PATH=${USER_HOME}/traffic_checker.py
DISPLAY=:99

# ── Check Schedule ────────────────────────────────────────────
CHECK_FREQUENCY=daily
CHECK_TIME_1=08:00
CHECK_TIME_2=20:00

# ── Admin Login ───────────────────────────────────────────────
FILAMENT_ADMIN_EMAIL=admin@${DOMAIN}
FILAMENT_ADMIN_PASSWORD=CHANGE_THIS_NOW
ENV

ok ".env created at $APP_DIR/.env"
warn "Edit .env to add your email password, WhatsApp keys, and admin password"

# ── 4. Install PHP dependencies ───────────────────────────────
echo ""
echo "[4/8] Running composer install..."
cd "$APP_DIR"
$BEST_PHP /usr/local/bin/composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress 2>&1 | grep -E "(Installing|Generating|Nothing)" | head -10
ok "Composer packages installed"

# ── 5. Laravel setup ──────────────────────────────────────────
echo ""
echo "[5/8] Running Laravel setup..."
cd "$APP_DIR"
$BEST_PHP artisan key:generate --force
ok "App key generated"

$BEST_PHP artisan migrate --force --seed
ok "Database migrated and seeded"

$BEST_PHP artisan config:cache
$BEST_PHP artisan route:cache
$BEST_PHP artisan view:cache
ok "Config/route/view cache built"

# storage:link creates public/storage → storage/app/public
$BEST_PHP artisan storage:link 2>/dev/null || true
ok "Storage link created"

# ── 6. File permissions ───────────────────────────────────────
echo ""
echo "[6/8] Setting file permissions..."
chown -R "$CPANEL_USER:$CPANEL_USER" "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
# Python scripts
[ -f "$USER_HOME/traffic_checker.py" ]    && chmod 755 "$USER_HOME/traffic_checker.py"
[ -f "$APP_DIR/scripts/checker_wrapper.py" ] && chmod 755 "$APP_DIR/scripts/checker_wrapper.py"
ok "Permissions set"

# ── 7. cPanel cron job ───────────────────────────────────────
echo ""
echo "[7/8] Configuring cron job..."

CRON_CMD="* * * * * $BEST_PHP $APP_DIR/artisan schedule:run >> /dev/null 2>&1"
# Add for the cPanel user
(crontab -u "$CPANEL_USER" -l 2>/dev/null; echo "$CRON_CMD") | sort -u | crontab -u "$CPANEL_USER" -
ok "Cron job added for user: $CPANEL_USER"
echo "  Command: $CRON_CMD"

# ── 8. Domain document root info ─────────────────────────────
echo ""
echo "[8/8] Web server configuration..."
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  POINT YOUR DOMAIN DOCUMENT ROOT TO:                    │"
echo "  │                                                          │"
echo "  │  $APP_DIR/public"
echo "  │                                                          │"
echo "  │  In WHM: Account Functions → Modify Account             │"
echo "  │  OR cPanel → Domains → Edit your domain                 │"
echo "  │  Change Document Root to: traffic-checker/public        │"
echo "  │                                                          │"
echo "  │  For SUBDOMAIN (recommended):                            │"
echo "  │  cPanel → Domains → Create New Domain                   │"
echo "  │  traffic.$DOMAIN → traffic-checker/public"
echo "  └──────────────────────────────────────────────────────────┘"

# Quick test
echo ""
echo "  Testing artisan command..."
cd "$APP_DIR"
$BEST_PHP artisan --version && ok "Laravel is working" || warn "Laravel test failed — check error log"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Deploy complete!                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  DB Name  : $DB_NAME                    "
echo "║  DB User  : $DB_USER                    "
echo "║  DB Pass  : $DB_PASS"
echo "║                                                              ║"
echo "║  TODO (in order):                                            ║"
echo "║  1. Set domain doc root → traffic-checker/public            ║"
echo "║  2. nano $APP_DIR/.env                   "
echo "║     → Set MAIL_PASSWORD                                      ║"
echo "║     → Set WHATSAPP_INSTANCE_ID + ACCESS_TOKEN               ║"
echo "║     → Set FILAMENT_ADMIN_PASSWORD                            ║"
echo "║  3. php artisan config:cache  (after editing .env)           ║"
echo "║  4. Visit https://$DOMAIN → login → add vehicles"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
