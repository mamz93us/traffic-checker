#!/bin/bash
# =============================================================================
#  Traffic Checker — Clean Ubuntu 22.04 / 24.04 Server Setup
#  - Resumes safely: skips already-installed components
#  - Full output visible for tracing errors
#  Run as root:  bash scripts/ubuntu_setup.sh
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_DIR="/var/www/traffic-checker"
APP_USER="www-data"
REPO_URL="https://github.com/mamz93us/traffic-checker.git"
REPO_BRANCH="claude/epic-solomon"
PHP_VER="8.3"
DOMAIN="${DOMAIN:-t.samirgroup.net}"
DB_NAME="${DB_NAME:-traffic_checker}"
DB_USER="${DB_USER:-traffic_user}"
DB_PASS_FILE="/root/.tc_db_pass"
DB_ROOT_PASS_FILE="/root/.tc_db_root_pass"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()      { echo -e "${GREEN}  ✓ $1${NC}"; }
skip()    { echo -e "${CYAN}  ↷ $1 — already done, skipping${NC}"; }
fail()    { echo -e "${RED}  ✗ $1${NC}"; exit 1; }
info()    { echo -e "\n${YELLOW}━━ $1 ━━${NC}"; }
installed() { command -v "$1" &>/dev/null; }

# Load or generate DB passwords (persist across re-runs)
if [ -f "$DB_PASS_FILE" ]; then
    DB_PASS=$(cat "$DB_PASS_FILE")
else
    DB_PASS=$(openssl rand -base64 18 | tr -d '/+=')
    echo "$DB_PASS" > "$DB_PASS_FILE"
    chmod 600 "$DB_PASS_FILE"
fi
if [ -f "$DB_ROOT_PASS_FILE" ]; then
    DB_ROOT_PASS=$(cat "$DB_ROOT_PASS_FILE")
else
    DB_ROOT_PASS=$(openssl rand -base64 18 | tr -d '/+=')
    echo "$DB_ROOT_PASS" > "$DB_ROOT_PASS_FILE"
    chmod 600 "$DB_ROOT_PASS_FILE"
fi

echo ""
echo "============================================================"
echo "  Traffic Checker — Ubuntu Server Setup"
echo "  Domain : $DOMAIN"
echo "  App dir: $APP_DIR"
echo "  DB name: $DB_NAME / user: $DB_USER"
echo "============================================================"

# ── 1. System update ──────────────────────────────────────────────────────────
info "Step 1: System update"
apt-get update
apt-get upgrade -y
ok "System updated"

# ── 2. Essential tools ────────────────────────────────────────────────────────
info "Step 2: Essential tools"
apt-get install -y \
    curl wget git unzip zip gnupg2 ca-certificates lsb-release \
    software-properties-common apt-transport-https
ok "Essential tools installed"

# ── 3. PHP 8.3 ───────────────────────────────────────────────────────────────
info "Step 3: PHP $PHP_VER"
if php${PHP_VER} --version &>/dev/null; then
    skip "PHP $PHP_VER"
else
    echo "  Adding ppa:ondrej/php..."
    add-apt-repository -y ppa:ondrej/php
    apt-get update
    apt-get install -y \
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
    ok "PHP $PHP_VER installed"
fi
php${PHP_VER} --version

# ── 4. Composer ───────────────────────────────────────────────────────────────
info "Step 4: Composer"
if installed composer; then
    skip "Composer ($(composer --version | head -1))"
else
    curl -sS https://getcomposer.org/installer | php${PHP_VER} -- --install-dir=/usr/local/bin --filename=composer
    ok "Composer installed: $(composer --version | head -1)"
fi

# ── 5. MySQL ──────────────────────────────────────────────────────────────────
info "Step 5: MySQL"
if systemctl is-active --quiet mysql 2>/dev/null; then
    skip "MySQL (already running)"
else
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    systemctl enable mysql
    systemctl start mysql
    ok "MySQL installed and started"
fi

# Create DB/user — detect whether root uses auth_socket or password
echo "  Detecting MySQL root auth method..."
if mysql -e "SELECT 1;" > /dev/null 2>&1; then
    MYSQL_CMD="mysql"
    echo "  Using auth_socket (no password)"
elif mysql -u root -p"${DB_ROOT_PASS}" -e "SELECT 1;" > /dev/null 2>&1; then
    MYSQL_CMD="mysql -u root -p${DB_ROOT_PASS}"
    echo "  Using stored root password"
else
    echo "  WARNING: Cannot connect to MySQL as root — skipping DB setup"
    echo "  Run manually: mysql -u root  then create DB/user"
    MYSQL_CMD=""
fi

if [ -n "$MYSQL_CMD" ]; then
    $MYSQL_CMD <<SQL
  CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
  GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
  FLUSH PRIVILEGES;
SQL
    ok "Database ready: $DB_NAME / $DB_USER"
fi

# ── 6. Nginx ──────────────────────────────────────────────────────────────────
info "Step 6: Nginx"
if systemctl is-active --quiet nginx 2>/dev/null; then
    skip "Nginx (already running)"
else
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    ok "Nginx installed and started"
fi

# ── 7. Python 3 + Playwright ─────────────────────────────────────────────────
info "Step 7: Python 3 + Playwright + Chromium"
apt-get install -y python3 python3-pip python3-venv

if python3 -c "import playwright" &>/dev/null; then
    skip "Playwright Python package"
else
    pip3 install playwright --break-system-packages
    ok "Playwright installed"
fi

CHROMIUM_BIN=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1 || true)
if [ -n "$CHROMIUM_BIN" ] && [ -f "$CHROMIUM_BIN" ]; then
    skip "Playwright Chromium (found at $CHROMIUM_BIN)"
else
    echo "  Installing Playwright Chromium browser..."
    python3 -m playwright install chromium
    echo "  Installing Chromium OS dependencies..."
    python3 -m playwright install-deps chromium
    CHROMIUM_BIN=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1 || true)
    ok "Chromium installed at: $CHROMIUM_BIN"
fi

# ── 8. Node.js ────────────────────────────────────────────────────────────────
info "Step 8: Node.js 20"
if installed node; then
    skip "Node.js ($(node --version))"
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    ok "Node.js installed: $(node --version)"
fi

# ── 9. Clone / update repo ───────────────────────────────────────────────────
info "Step 9: Repository"
if [ -d "$APP_DIR/.git" ]; then
    echo "  Repo exists — pulling latest..."
    git -C "$APP_DIR" fetch origin
    git -C "$APP_DIR" checkout "$REPO_BRANCH"
    git -C "$APP_DIR" pull origin "$REPO_BRANCH"
    ok "Repository updated"
else
    echo "  Cloning $REPO_URL branch $REPO_BRANCH..."
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
    ok "Repository cloned"
fi

# ── 10. Composer dependencies ─────────────────────────────────────────────────
info "Step 10: PHP dependencies (composer install)"
# bootstrap/cache must exist before composer runs post-install scripts
mkdir -p "$APP_DIR/bootstrap/cache"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR/bootstrap"
chmod -R 775 "$APP_DIR/bootstrap/cache"
COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_NO_INTERACTION=1 composer install --working-dir="$APP_DIR" --no-dev --optimize-autoloader --no-interaction
ok "PHP dependencies installed"

# ── 11. .env setup ─────────────────────────────────────────────────────────────
info "Step 11: .env configuration"
if [ ! -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/.env.example" "$APP_DIR/.env"
    sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" "$APP_DIR/.env"
    sed -i "s|DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$APP_DIR/.env"
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" "$APP_DIR/.env"
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" "$APP_DIR/.env"
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" "$APP_DIR/.env"
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=file|" "$APP_DIR/.env"
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=file|" "$APP_DIR/.env"
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=database|" "$APP_DIR/.env"
    sed -i 's|CHECK_FREQUENCY=.*|CHECK_FREQUENCY=daily|' "$APP_DIR/.env"
    sed -i 's|CHECK_TIME_1=.*|CHECK_TIME_1=08:00|' "$APP_DIR/.env"
    sed -i 's|CHECK_TIME_2=.*|CHECK_TIME_2=20:00|' "$APP_DIR/.env"
    sed -i "s|PYTHON_SCRIPT_PATH=.*|PYTHON_SCRIPT_PATH=${APP_DIR}/traffic_checker.py|" "$APP_DIR/.env"
    sed -i "s|PYTHON_BIN=.*|PYTHON_BIN=/usr/bin/python3|" "$APP_DIR/.env"
    if [ -n "$CHROMIUM_BIN" ]; then
        sed -i "s|PLAYWRIGHT_CHROMIUM_PATH=.*|PLAYWRIGHT_CHROMIUM_PATH=${CHROMIUM_BIN}|" "$APP_DIR/.env"
    fi
    ok ".env created"
else
    skip ".env (already exists)"
fi

# ── 12. Storage & permissions ─────────────────────────────────────────────────
info "Step 12: Storage directories and permissions"
mkdir -p "$APP_DIR/storage/framework/"{sessions,views,cache/data}
mkdir -p "$APP_DIR/storage/logs"
mkdir -p "$APP_DIR/bootstrap/cache"
touch "$APP_DIR/storage/logs/laravel.log"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
chmod +x "$APP_DIR/artisan"
ok "Permissions set"

# ── 13. Laravel artisan setup ─────────────────────────────────────────────────
info "Step 13: Laravel setup"
cd "$APP_DIR"

echo "  → key:generate"
php artisan key:generate --force

echo "  → config:cache"
php artisan config:cache

echo "  → route:cache"
php artisan route:cache

echo "  → view:cache"
php artisan view:cache

echo "  → migrate --seed"
php artisan migrate --force --seed

echo "  → storage:link"
php artisan storage:link 2>/dev/null || true

ok "Laravel configured"

# ── 14. Nginx virtual host ────────────────────────────────────────────────────
info "Step 14: Nginx virtual host"
cat > /etc/nginx/sites-available/traffic-checker << NGINX
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${APP_DIR}/public;
    index index.php;
    charset utf-8;

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
nginx -t
systemctl reload nginx
ok "Nginx configured for $DOMAIN"

# ── 15. Certbot ───────────────────────────────────────────────────────────────
info "Step 15: Certbot (SSL)"
if installed certbot; then
    skip "Certbot"
else
    apt-get install -y certbot python3-certbot-nginx
    ok "Certbot installed"
fi

# ── 16. Cron ─────────────────────────────────────────────────────────────────
info "Step 16: Laravel scheduler cron"
if crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
    skip "Cron job"
else
    (crontab -l 2>/dev/null; echo "* * * * * $APP_USER php $APP_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -
    ok "Cron job added"
fi

# ── 17. Supervisor ────────────────────────────────────────────────────────────
info "Step 17: Supervisor (queue worker)"
if installed supervisord || installed supervisorctl; then
    skip "Supervisor (already installed)"
else
    apt-get install -y supervisor
    ok "Supervisor installed"
fi

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

supervisorctl reread
supervisorctl update
ok "Supervisor configured"

# ── 18. UFW Firewall ─────────────────────────────────────────────────────────
info "Step 18: UFW Firewall"
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ok "Firewall configured"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN}  ✅  Setup complete!${NC}"
echo "============================================================"
echo ""
echo "  URL      : http://${DOMAIN}"
echo "  App      : $APP_DIR"
echo "  DB name  : $DB_NAME"
echo "  DB user  : $DB_USER"
echo "  DB pass  : $DB_PASS"
echo "  DB root  : $DB_ROOT_PASS"
echo ""
echo -e "${YELLOW}  ⚠  Save the passwords above!${NC}"
echo ""
echo "  Next steps:"
echo "  1. Copy traffic_checker.py to: $APP_DIR/traffic_checker.py"
echo "  2. Edit $APP_DIR/.env — set FILAMENT_ADMIN_EMAIL + FILAMENT_ADMIN_PASSWORD"
echo "  3. Re-seed admin:  php $APP_DIR/artisan db:seed --class=AdminUserSeeder"
echo "  4. Enable SSL:     certbot --nginx -d ${DOMAIN} --agree-tos -m your@email.com"
echo ""
echo "  Login: http://${DOMAIN}/login"
echo "============================================================"
