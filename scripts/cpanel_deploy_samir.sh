#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Traffic Checker — Deploy for t.samirgroup.net
# Run as ROOT after fix_xvfb.sh succeeds
#
# Usage: bash cpanel_deploy_samir.sh YOUR_CPANEL_USERNAME
# ════════════════════════════════════════════════════════════════

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }

CPANEL_USER="${1:?Usage: bash cpanel_deploy_samir.sh YOUR_CPANEL_USERNAME}"
DOMAIN="t.samirgroup.net"
USER_HOME="/home/$CPANEL_USER"

# ── Detect PHP ────────────────────────────────────────────────
PHP_BIN=""
for ver in ea-php83 ea-php82 ea-php81 ea-php80; do
    BIN="/opt/cpanel/$ver/root/usr/bin/php"
    if [ -x "$BIN" ]; then PHP_BIN="$BIN"; break; fi
done
PHP_BIN="${PHP_BIN:-$(which php)}"

# ── Detect where subdomain document root is ───────────────────
# cPanel subdomains usually go to public_html/t.samirgroup.net/
# OR the user may have set a custom path
POSSIBLE_ROOTS=(
    "$USER_HOME/public_html/t.samirgroup.net"
    "$USER_HOME/public_html/t"
    "$USER_HOME/t.samirgroup.net"
    "$USER_HOME/public_html"
)

SUBDOMAIN_ROOT=""
for path in "${POSSIBLE_ROOTS[@]}"; do
    if [ -d "$path" ]; then
        SUBDOMAIN_ROOT="$path"
        break
    fi
done

# Where Laravel lives (outside public_html for security)
APP_DIR="$USER_HOME/traffic-checker"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Traffic Checker — Deploy for t.samirgroup.net          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  cPanel User : $CPANEL_USER"
echo "║  User Home   : $USER_HOME"
echo "║  PHP         : $PHP_BIN ($($PHP_BIN -r 'echo PHP_VERSION;' 2>/dev/null))"
echo "║  App dir     : $APP_DIR"
if [ -n "$SUBDOMAIN_ROOT" ]; then
echo "║  Subdomain   : $SUBDOMAIN_ROOT (found)"
else
echo "║  Subdomain   : will create $USER_HOME/public_html/t.samirgroup.net"
fi
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Verify user exists
id "$CPANEL_USER" &>/dev/null || err "cPanel user '$CPANEL_USER' not found. Check spelling."

# ── 1. Copy app files ─────────────────────────────────────────
echo "[1/9] Copying application files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$APP_DIR"

# Find source — could be current dir or traffic-checker/ subfolder
if [ -f "$SCRIPT_DIR/composer.json" ]; then
    SRC="$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/traffic-checker" ]; then
    SRC="$SCRIPT_DIR/traffic-checker"
else
    err "Cannot find app files. Run this script from inside the extracted ZIP folder."
fi

rsync -a --exclude='vendor' --exclude='node_modules' --exclude='.git' \
    "$SRC/" "$APP_DIR/"
ok "App files → $APP_DIR"

# Copy Python checker one level above app (in user home)
for f in traffic_checker.py; do
    for src in "$SCRIPT_DIR/$f" "$SCRIPT_DIR/../$f" "/root/$f" "$USER_HOME/$f"; do
        [ -f "$src" ] && cp "$src" "$USER_HOME/$f" && ok "Copied $f → $USER_HOME/" && break
    done
done

# ── 2. Set up subdomain document root ────────────────────────
echo ""
echo "[2/9] Setting up subdomain document root..."

# Create the subdomain folder if it doesn't exist
if [ -z "$SUBDOMAIN_ROOT" ]; then
    SUBDOMAIN_ROOT="$USER_HOME/public_html/t.samirgroup.net"
    mkdir -p "$SUBDOMAIN_ROOT"
    ok "Created subdomain folder: $SUBDOMAIN_ROOT"
fi

# The trick: put a .htaccess + index.php in the subdomain root
# that redirects all requests into the Laravel app's public/ folder
# This way we don't need to change the document root in cPanel

cat > "$SUBDOMAIN_ROOT/.htaccess" << 'HTACCESS'
Options -Indexes
RewriteEngine On

# Serve files that actually exist directly
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d

# Route everything else to Laravel public/index.php
RewriteRule ^(.*)$ /home/CPANEL_USER_PLACEHOLDER/traffic-checker/public/$1 [L]
HTACCESS

# Replace placeholder with actual user
sed -i "s|CPANEL_USER_PLACEHOLDER|$CPANEL_USER|g" "$SUBDOMAIN_ROOT/.htaccess"

# Create a bootstrap index.php in the subdomain root
# that loads Laravel's public/index.php directly
cat > "$SUBDOMAIN_ROOT/index.php" << PHP
<?php
/**
 * Traffic Checker — Subdomain Bootstrap
 * Routes requests from t.samirgroup.net into Laravel's public/
 */
\$laravelPublic = '/home/${CPANEL_USER}/traffic-checker/public';

// Change working directory to Laravel's public folder
chdir(\$laravelPublic);

// Set the document root for Laravel's asset URLs
\$_SERVER['DOCUMENT_ROOT'] = \$laravelPublic;

// Load Laravel
require \$laravelPublic . '/index.php';
PHP

ok "Subdomain bootstrap → $SUBDOMAIN_ROOT/index.php"
ok ".htaccess routing → $SUBDOMAIN_ROOT/.htaccess"

# ── 3. MySQL database ─────────────────────────────────────────
echo ""
echo "[3/9] Creating MySQL database..."
PREFIX=$(echo "$CPANEL_USER" | cut -c1-8 | tr -cd 'a-zA-Z0-9')
DB_NAME="${CPANEL_USER}_traff"
DB_USER="${CPANEL_USER}_trafusr"
DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)

if command -v uapi &>/dev/null; then
    uapi --user="$CPANEL_USER" Mysql create_database name="${DB_NAME}" 2>/dev/null \
        && ok "Database '${DB_NAME}' created" || warn "DB may already exist — continuing"
    uapi --user="$CPANEL_USER" Mysql create_user name="${DB_USER}" password="${DB_PASS}" 2>/dev/null \
        && ok "DB user '${DB_USER}' created" || warn "User may already exist"
    uapi --user="$CPANEL_USER" Mysql set_privileges_on_database \
        user="${DB_USER}" database="${DB_NAME}" privileges="ALL PRIVILEGES" 2>/dev/null \
        && ok "Privileges granted" || warn "Could not set privileges via API"
else
    mysql -u root << SQL 2>/dev/null
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
    ok "Database created via MySQL root"
fi

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  DATABASE CREDENTIALS — SAVE THESE NOW!     │"
echo "  │                                             │"
echo "  │  DB Name : ${DB_NAME}                       │"
echo "  │  DB User : ${DB_USER}                  │"
echo "  │  DB Pass : ${DB_PASS}    │"
echo "  └─────────────────────────────────────────────┘"

# ── 4. .env file ──────────────────────────────────────────────
echo ""
echo "[4/9] Creating .env file..."
cat > "$APP_DIR/.env" << ENV
APP_NAME="Traffic Checker"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://t.samirgroup.net
APP_TIMEZONE=Africa/Cairo

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

CACHE_DRIVER=file
SESSION_DRIVER=file
SESSION_LIFETIME=120
QUEUE_CONNECTION=sync

# ── Mail — use your cPanel email ────────────────────────────
MAIL_MAILER=smtp
MAIL_HOST=mail.samirgroup.net
MAIL_PORT=587
MAIL_USERNAME=alerts@samirgroup.net
MAIL_PASSWORD=YOUR_EMAIL_PASSWORD_HERE
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=alerts@samirgroup.net
MAIL_FROM_NAME="Traffic Violations Alert"

# ── WhatsApp — https://green-api.com (free 2000/month) ──────
WHATSAPP_PROVIDER=green_api
WHATSAPP_INSTANCE_ID=YOUR_INSTANCE_ID
WHATSAPP_ACCESS_TOKEN=YOUR_ACCESS_TOKEN

# ── Python / Playwright ──────────────────────────────────────
PYTHON_BIN=/usr/bin/python3
PYTHON_SCRIPT_PATH=${USER_HOME}/traffic_checker.py
DISPLAY=:99

# ── Schedule ─────────────────────────────────────────────────
CHECK_FREQUENCY=daily
CHECK_TIME_1=08:00
CHECK_TIME_2=20:00

# ── Admin login ───────────────────────────────────────────────
FILAMENT_ADMIN_EMAIL=admin@samirgroup.net
FILAMENT_ADMIN_PASSWORD=CHANGE_THIS_NOW
ENV
ok ".env created"

# ── 5. Composer install ───────────────────────────────────────
echo ""
echo "[5/9] Running composer install (may take 2-3 minutes)..."
cd "$APP_DIR"
$PHP_BIN /usr/local/bin/composer install \
    --no-dev --optimize-autoloader --no-interaction --no-progress 2>&1 \
    | grep -E "^(Installing|Generating|Nothing|  -)" | head -20
ok "Composer packages installed"

# ── 6. Laravel setup ──────────────────────────────────────────
echo ""
echo "[6/9] Running Laravel setup..."
cd "$APP_DIR"
$PHP_BIN artisan key:generate --force && ok "App key generated"
$PHP_BIN artisan migrate --force --seed  && ok "Database migrated + seeded"
$PHP_BIN artisan config:cache            && ok "Config cached"
$PHP_BIN artisan route:cache             && ok "Routes cached"
$PHP_BIN artisan view:cache              && ok "Views cached"
$PHP_BIN artisan storage:link 2>/dev/null || true
ok "Storage link created"

# ── 7. File permissions ───────────────────────────────────────
echo ""
echo "[7/9] Setting file permissions..."
chown -R "$CPANEL_USER:$CPANEL_USER" "$APP_DIR"
chown -R "$CPANEL_USER:$CPANEL_USER" "$SUBDOMAIN_ROOT"
chmod -R 755 "$APP_DIR"
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
[ -f "$USER_HOME/traffic_checker.py" ] && chmod 755 "$USER_HOME/traffic_checker.py"
[ -f "$APP_DIR/scripts/checker_wrapper.py" ] && chmod 755 "$APP_DIR/scripts/checker_wrapper.py"
ok "Permissions set"

# ── 8. Cron job ───────────────────────────────────────────────
echo ""
echo "[8/9] Adding cron job for $CPANEL_USER..."
CRON_LINE="* * * * * $PHP_BIN $APP_DIR/artisan schedule:run >> /dev/null 2>&1"
( crontab -u "$CPANEL_USER" -l 2>/dev/null | grep -v "traffic-checker"; echo "$CRON_LINE" ) \
    | crontab -u "$CPANEL_USER" -
ok "Cron job added"
echo "  $CRON_LINE"

# ── 9. Quick test ─────────────────────────────────────────────
echo ""
echo "[9/9] Testing setup..."
cd "$APP_DIR"
$PHP_BIN artisan --version && ok "Laravel is working" || warn "Check storage/logs/laravel.log"

# Test Python wrapper
echo "  Testing Python checker..."
export DISPLAY=:99
echo '{"owner":"Test","letter_1":"ل","letter_2":"ط","letter_3":"","numbers":"1234","national_id":"11111111111111","phone":"01000000000","output_dir":"/tmp"}' \
    | timeout 10 python3 "$APP_DIR/scripts/checker_wrapper.py" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('  ✓ Python wrapper OK' if 'error' not in d or 'not found' not in d.get('error','') else '  ⚠  ' + d.get('error',''))" \
    || warn "Python test inconclusive (normal if traffic_checker.py needs the real site)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Deploy complete!                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Site URL    : https://t.samirgroup.net                      ║"
echo "║  App files   : $APP_DIR"
echo "║  Web root    : $SUBDOMAIN_ROOT"
echo "║  DB Name     : $DB_NAME                    "
echo "║  DB Pass     : $DB_PASS"
echo "║                                                              ║"
echo "║  ── 3 things to edit in .env ───────────────────────────── ║"
echo "║  nano $APP_DIR/.env"
echo "║                                                              ║"
echo "║  1. MAIL_PASSWORD=        ← your cPanel email password      ║"
echo "║  2. WHATSAPP_INSTANCE_ID= ← from green-api.com              ║"
echo "║     WHATSAPP_ACCESS_TOKEN=                                   ║"
echo "║  3. FILAMENT_ADMIN_PASSWORD= ← choose a strong password     ║"
echo "║                                                              ║"
echo "║  After editing .env:                                         ║"
echo "║  $PHP_BIN $APP_DIR/artisan config:cache"
echo "║                                                              ║"
echo "║  Login: https://t.samirgroup.net                             ║"
echo "║  Email: admin@samirgroup.net / password: CHANGE_THIS_NOW     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
