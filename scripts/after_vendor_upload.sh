#!/bin/bash
# Run as ROOT after uploading vendor/ folder
# ════════════════════════════════════════════════════════════════

PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Traffic Checker — Final Setup                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check vendor exists
[ -f "$APP/vendor/autoload.php" ] || { err "vendor/autoload.php not found — did you upload vendor/?"; exit 1; }
ok "vendor/ folder found"

cd "$APP"

# Check PHP extensions
echo ""
echo "Checking PHP extensions..."
MISSING=""
for ext in mbstring xml curl zip bcmath pdo_mysql json tokenizer; do
    if $PHP -m 2>/dev/null | grep -q "^$ext$"; then
        ok "$ext"
    else
        warn "$ext MISSING — installing..."
        dnf install -y "ea-php83-php-$ext" 2>/dev/null | grep -E "Installed|Nothing" || true
        MISSING="$MISSING $ext"
    fi
done

echo ""
echo "Running Laravel setup..."
$PHP artisan key:generate --force    && ok "App key generated"  || err "key:generate failed — check PHP extensions above"
$PHP artisan migrate --force --seed  && ok "DB migrated + admin user created" || err "migrate failed"
$PHP artisan config:cache            && ok "Config cached"      || warn "config:cache failed"
$PHP artisan route:cache             && ok "Routes cached"      || warn "route:cache failed"
$PHP artisan view:cache              && ok "Views cached"       || warn "view:cache failed"
$PHP artisan storage:link 2>/dev/null || true
ok "Storage link"

echo ""
echo "Setting permissions..."
chown -R samirgroupnet:samirgroupnet "$APP"
chmod -R 755 "$APP"
chmod 755 "$APP/artisan"
chmod -R 775 "$APP/storage"
chmod -R 775 "$APP/bootstrap/cache"
ok "Permissions set"

echo ""
echo "Verifying..."
$PHP artisan --version && ok "Laravel working!" || err "Still failing — paste output"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Setup complete!                                         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Visit : https://t.samirgroup.net                            ║"
echo "║  Login : admin@t.samirgroup.net                              ║"
echo "║  Pass  : CHANGE_THIS_NOW (edit .env first!)                  ║"
echo "║                                                              ║"
echo "║  Edit .env:                                                  ║"
echo "║  nano /home/samirgroupnet/traffic-checker/.env              ║"
echo "║                                                              ║"
echo "║  Change:                                                     ║"
echo "║  FILAMENT_ADMIN_PASSWORD=your_password                       ║"
echo "║  MAIL_PASSWORD=your_cpanel_email_password                    ║"
echo "║  WHATSAPP_INSTANCE_ID=from_green-api.com                     ║"
echo "║  WHATSAPP_ACCESS_TOKEN=from_green-api.com                    ║"
echo "║                                                              ║"
echo "║  Then: php artisan config:cache                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
