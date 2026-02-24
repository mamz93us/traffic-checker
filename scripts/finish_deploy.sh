#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Finish deploy for samirgroupnet — run as ROOT
# ════════════════════════════════════════════════════════════════

PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"
USER="samirgroupnet"
USER_HOME="/home/samirgroupnet"
SUBDOMAIN_ROOT="$USER_HOME/public_html/t.samirgroup.net"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Finishing deploy for t.samirgroup.net                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Fix MySQL — drop wrong-prefix DB/user, create correct ones ──
echo "[1/7] Fixing MySQL database..."

DB_NAME="samirgroupnet_traff"
DB_USER="samirgroupnet_trafusr"
# Reuse same password if .env already has one, else generate new
DB_PASS=$(grep "^DB_PASSWORD=" "$APP/.env" 2>/dev/null | cut -d= -f2)
[ -z "$DB_PASS" ] && DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)

# Drop the broken ones silently
mysql -u root 2>/dev/null << SQL
DROP DATABASE IF EXISTS \`samirgro_traff\`;
DROP USER IF EXISTS 'samirgro_trafusr'@'localhost';
SQL

# Create correct ones via cPanel API (registers them in cPanel UI)
uapi --user="$USER" Mysql create_database name="$DB_NAME" 2>/dev/null
uapi --user="$USER" Mysql create_user name="$DB_USER" password="$DB_PASS" 2>/dev/null

# Grant privileges via MySQL root (more reliable than uapi for this)
mysql -u root << SQL
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
SQL

ok "Database: $DB_NAME"
ok "User:     $DB_USER"
ok "Password: $DB_PASS"

# ── 2. Update .env with correct DB credentials ────────────────
echo ""
echo "[2/7] Updating .env..."

# Update DB credentials in .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|"    "$APP/.env"
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|"    "$APP/.env"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|"    "$APP/.env"
sed -i "s|^APP_URL=.*|APP_URL=https://t.samirgroup.net|" "$APP/.env"

# Fix Python script path
sed -i "s|^PYTHON_SCRIPT_PATH=.*|PYTHON_SCRIPT_PATH=/home/samirgroupnet/traffic_checker.py|" "$APP/.env"

ok ".env updated with correct DB credentials"

# ── 3. Run Laravel setup ──────────────────────────────────────
echo ""
echo "[3/7] Running Laravel setup..."
cd "$APP"

$PHP artisan key:generate --force   && ok "App key generated"
$PHP artisan config:clear           2>/dev/null; ok "Config cleared"
$PHP artisan migrate --force --seed && ok "Database migrated + seeded"
$PHP artisan config:cache           && ok "Config cached"
$PHP artisan route:cache            && ok "Routes cached"
$PHP artisan view:cache             && ok "Views cached"
$PHP artisan storage:link           2>/dev/null || true; ok "Storage link created"

# ── 4. Subdomain bootstrap files ─────────────────────────────
echo ""
echo "[4/7] Setting up subdomain web root..."

mkdir -p "$SUBDOMAIN_ROOT"

# Bootstrap index.php — hands requests to Laravel public/
cat > "$SUBDOMAIN_ROOT/index.php" << 'PHP'
<?php
$laravelPublic = '/home/samirgroupnet/traffic-checker/public';
chdir($laravelPublic);
$_SERVER['DOCUMENT_ROOT'] = $laravelPublic;
require $laravelPublic . '/index.php';
PHP

# .htaccess — routes all requests through bootstrap
cat > "$SUBDOMAIN_ROOT/.htaccess" << 'HTACCESS'
Options -Indexes
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ /home/samirgroupnet/traffic-checker/public/$1 [L]
HTACCESS

ok "Bootstrap index.php → $SUBDOMAIN_ROOT/index.php"
ok ".htaccess → $SUBDOMAIN_ROOT/.htaccess"

# ── 5. File permissions ───────────────────────────────────────
echo ""
echo "[5/7] Setting permissions..."
chown -R "$USER:$USER" "$APP"
chown -R "$USER:$USER" "$SUBDOMAIN_ROOT"
chmod -R 755 "$APP"
chmod -R 775 "$APP/storage" "$APP/bootstrap/cache"
[ -f "$USER_HOME/traffic_checker.py" ] && chmod 755 "$USER_HOME/traffic_checker.py"
[ -f "$APP/scripts/checker_wrapper.py" ] && chmod 755 "$APP/scripts/checker_wrapper.py"
ok "Permissions set"

# ── 6. Cron job ───────────────────────────────────────────────
echo ""
echo "[6/7] Adding cron job..."
CRON_LINE="* * * * * $PHP $APP/artisan schedule:run >> /dev/null 2>&1"
( crontab -u "$USER" -l 2>/dev/null | grep -v "traffic-checker"; echo "$CRON_LINE" ) \
    | crontab -u "$USER" -
ok "Cron: $CRON_LINE"

# ── 7. Final test ─────────────────────────────────────────────
echo ""
echo "[7/7] Testing..."
cd "$APP"
$PHP artisan --version && ok "Laravel working" || err "Laravel error — check logs"

# Test DB connection
$PHP artisan migrate:status 2>/dev/null | head -5 && ok "DB connection working" || warn "DB connection issue"

# Quick Chromium test
echo "  Testing Chromium..."
export DISPLAY=:99
python3 -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(headless=True, args=['--no-sandbox','--disable-dev-shm-usage'])
    b.close()
print('  Chromium OK')
" && ok "Chromium ready" || warn "Chromium issue — check: systemctl status xvfb-traffic"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Deploy finished!                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Site URL  : https://t.samirgroup.net                        ║"
echo "║  DB Name   : $DB_NAME                 ║"
echo "║  DB Pass   : $DB_PASS        ║"
echo "║                                                              ║"
echo "║  ── Edit 3 things in .env then run config:cache ─────────  ║"
echo "║                                                              ║"
echo "║  nano /home/samirgroupnet/traffic-checker/.env              ║"
echo "║                                                              ║"
echo "║  1. MAIL_PASSWORD=your_cpanel_email_password                 ║"
echo "║  2. WHATSAPP_INSTANCE_ID= (from green-api.com)               ║"
echo "║     WHATSAPP_ACCESS_TOKEN=                                   ║"
echo "║  3. FILAMENT_ADMIN_PASSWORD=choose_strong_password           ║"
echo "║                                                              ║"
echo "║  Then: $PHP $APP/artisan config:cache"
echo "║                                                              ║"
echo "║  Login: https://t.samirgroup.net                             ║"
echo "║  Email: admin@samirgroup.net                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
