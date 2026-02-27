#!/bin/bash
# =============================================================================
#  Traffic Checker — Clean Ubuntu 22.04 / 24.04 Server Setup
#  Run as root on a fresh server:  bash scripts/ubuntu_setup.sh
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_DIR="/var/www/traffic-checker"
APP_USER="www-data"
REPO_URL="https://github.com/mamz93us/traffic-checker.git"
REPO_BRANCH="claude/epic-solomon"          # change to main after PR merge
PHP_VER="8.3"
DOMAIN="${DOMAIN:-t.samirgroup.net}"       # override: DOMAIN=example.com bash ubuntu_setup.sh
DB_NAME="${DB_NAME:-traffic_checker}"
DB_USER="${DB_USER:-traffic_user}"
DB_PASS="${DB_PASS:-$(openssl rand -base64 18 | tr -d '/+=')}"
DB_ROOT_PASS="${DB_ROOT_PASS:-$(openssl rand -base64 18 | tr -d '/+=')}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}▸ $1${NC}"; }

echo "============================================================"
echo "  Traffic Checker — Ubuntu Server Setup"
echo "  Domain : $DOMAIN"
echo "  App dir: $APP_DIR"
echo "============================================================"

# ── 1. System update ──────────────────────────────────────────────────────────
info "Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq
ok "System updated"

# ── 2. Essential tools ────────────────────────────────────────────────────────
info "Installing essential tools..."
apt-get install -y -qq \
    curl wget git unzip zip gnupg2 ca-certificates lsb-release \
    software-properties-common apt-transport-https
ok "Essential tools installed"

# ── 3. PHP 8.3 ───────────────────────────────────────────────────────────────
info "Installing PHP $PHP_VER..."
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get update -qq
apt-get install -y -qq \
    php${PHP_VER}-fpm \
    php${PHP_VER}-cli \
    php${PHP_VER}-mysql \
    php${PHP_VER}-sqlite3 \
    php${PHP_VER}-mbstring \
    php${PHP_VER}-xml \
    php${PHP_VER}-curl \
    php${PHP_VER}-zip \
    php${PHP_VER}-bcmath \
    php${PHP_VER}-gd \
    php${PHP_VER}-intl \
    php${PHP_VER}-redis
# Note: openssl, tokenizer, fileinfo are built into PHP core on Ubuntu — no separate package needed
ok "PHP $PHP_VER installed"

# ── 4. Composer ───────────────────────────────────────────────────────────────
info "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null
ok "Composer installed: $(composer --version 2>/dev/null | head -1)"

# ── 5. MySQL ──────────────────────────────────────────────────────────────────
info "Installing MySQL..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mysql-server

# Secure MySQL and create DB/user
mysql -u root <<SQL
  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASS}';
  CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
  GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
  FLUSH PRIVILEGES;
SQL
ok "MySQL installed — DB: $DB_NAME | User: $DB_USER"

# ── 6. Nginx ──────────────────────────────────────────────────────────────────
info "Installing Nginx..."
apt-get install -y -qq nginx
ok "Nginx installed"

# ── 7. Python 3 + pip + Playwright ───────────────────────────────────────────
info "Installing Python 3 + Playwright..."
apt-get install -y -qq python3 python3-pip python3-venv

pip3 install playwright --break-system-packages 2>/dev/null || \
pip3 install playwright

# Install Playwright's Chromium and all its OS dependencies
python3 -m playwright install chromium
python3 -m playwright install-deps chromium
ok "Python + Playwright + Chromium installed"

# ── 8. Node.js (for frontend assets) ─────────────────────────────────────────
info "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs
ok "Node.js installed: $(node --version)"

# ── 9. Clone / update repo ───────────────────────────────────────────────────
info "Cloning repository..."
if [ -d "$APP_DIR/.git" ]; then
    git -C "$APP_DIR" pull origin "$REPO_BRANCH"
    ok "Repository updated"
else
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
    ok "Repository cloned"
fi

# ── 10. Composer dependencies ─────────────────────────────────────────────────
info "Installing PHP dependencies..."
composer install --working-dir="$APP_DIR" --no-dev --optimize-autoloader --no-interaction -q
ok "PHP dependencies installed"

# ── 11. .env setup ─────────────────────────────────────────────────────────────
info "Setting up .env..."
if [ ! -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/.env.example" "$APP_DIR/.env"

    # Auto-fill generated values
    sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" "$APP_DIR/.env"
    sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$APP_DIR/.env"
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" "$APP_DIR/.env"
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" "$APP_DIR/.env"
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" "$APP_DIR/.env"
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=file|" "$APP_DIR/.env"
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=file|" "$APP_DIR/.env"
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=database|" "$APP_DIR/.env"

    # Fix inline comments in .env
    sed -i 's|CHECK_FREQUENCY=daily.*|CHECK_FREQUENCY=daily|' "$APP_DIR/.env"
    sed -i 's|CHECK_TIME_1=08:00.*|CHECK_TIME_1=08:00|' "$APP_DIR/.env"
    sed -i 's|CHECK_TIME_2=20:00.*|CHECK_TIME_2=20:00|' "$APP_DIR/.env"

    # Set Playwright Chromium path (installed by Playwright for root)
    CHROMIUM_PATH=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1 || true)
    if [ -n "$CHROMIUM_PATH" ]; then
        sed -i "s|PLAYWRIGHT_CHROMIUM_PATH=.*|PLAYWRIGHT_CHROMIUM_PATH=${CHROMIUM_PATH}|" "$APP_DIR/.env"
    fi

    # Set Python script path
    sed -i "s|PYTHON_SCRIPT_PATH=.*|PYTHON_SCRIPT_PATH=${APP_DIR}/traffic_checker.py|" "$APP_DIR/.env"
    sed -i "s|PYTHON_BIN=.*|PYTHON_BIN=/usr/bin/python3|" "$APP_DIR/.env"

    ok ".env created"
else
    ok ".env already exists — skipping"
fi

# ── 12. Storage & permissions ─────────────────────────────────────────────────
info "Setting up storage and permissions..."
mkdir -p "$APP_DIR/storage/framework/"{sessions,views,cache/data}
mkdir -p "$APP_DIR/storage/logs"
mkdir -p "$APP_DIR/bootstrap/cache"
touch "$APP_DIR/storage/logs/laravel.log"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
chmod +x "$APP_DIR/artisan"
ok "Permissions set"

# ── 13. Laravel setup ─────────────────────────────────────────────────────────
info "Running Laravel setup..."
cd "$APP_DIR"
PHP_BIN="php"

$PHP_BIN artisan key:generate --force
$PHP_BIN artisan config:cache
$PHP_BIN artisan route:cache
$PHP_BIN artisan view:cache
$PHP_BIN artisan migrate --force --seed
$PHP_BIN artisan storage:link 2>/dev/null || true
ok "Laravel configured"

# ── 14. Nginx virtual host ────────────────────────────────────────────────────
info "Configuring Nginx..."
cat > /etc/nginx/sites-available/traffic-checker << NGINX
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${APP_DIR}/public;
    index index.php;
    charset utf-8;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/traffic-checker /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ok "Nginx configured for $DOMAIN"

# ── 15. SSL with Certbot ──────────────────────────────────────────────────────
info "Installing Certbot for SSL..."
apt-get install -y -qq certbot python3-certbot-nginx
echo ""
echo -e "${YELLOW}  To enable HTTPS run:${NC}"
echo "  certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}"
echo ""

# ── 16. Cron — Laravel scheduler ──────────────────────────────────────────────
info "Setting up cron job..."
CRON_JOB="* * * * * $APP_USER php $APP_DIR/artisan schedule:run >> /dev/null 2>&1"
if ! crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi
ok "Cron job added"

# ── 17. Supervisor for queue worker ──────────────────────────────────────────
info "Installing Supervisor..."
apt-get install -y -qq supervisor

cat > /etc/supervisor/conf.d/traffic-checker.conf << SUPERVISOR
[program:traffic-checker-worker]
process_name=%(program_name)s_%(process_num)02d
command=php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --max-time=3600
directory=${APP_DIR}
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=${APP_USER}
numprocs=1
redirect_stderr=true
stdout_logfile=${APP_DIR}/storage/logs/worker.log
stopwaitsecs=3600
SUPERVISOR

supervisorctl reread && supervisorctl update
ok "Supervisor configured"

# ── 18. UFW Firewall ──────────────────────────────────────────────────────────
info "Configuring firewall..."
apt-get install -y -qq ufw
ufw --force reset > /dev/null
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow ssh > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw --force enable > /dev/null
ok "Firewall configured (SSH, HTTP, HTTPS allowed)"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN}  ✅  Setup complete!${NC}"
echo "============================================================"
echo ""
echo "  App URL   : http://${DOMAIN}"
echo "  App dir   : $APP_DIR"
echo "  DB name   : $DB_NAME"
echo "  DB user   : $DB_USER"
echo "  DB pass   : $DB_PASS"
echo "  DB root   : $DB_ROOT_PASS"
echo ""
echo -e "${YELLOW}  IMPORTANT — save these credentials!${NC}"
echo ""
echo "  Next steps:"
echo "  1. Copy traffic_checker.py to: $APP_DIR/traffic_checker.py"
echo "  2. Edit $APP_DIR/.env and fill in:"
echo "       FILAMENT_ADMIN_EMAIL, FILAMENT_ADMIN_PASSWORD"
echo "       MAIL_*, WHATSAPP_* settings"
echo "  3. Enable SSL: certbot --nginx -d ${DOMAIN} --agree-tos -m your@email.com"
echo "  4. Re-seed admin user after updating .env:"
echo "       php $APP_DIR/artisan db:seed --class=AdminUserSeeder"
echo ""
echo "  Login at: http://${DOMAIN}/login"
echo "============================================================"
