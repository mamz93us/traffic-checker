#!/bin/bash
# ════════════════════════════════════════════════════════════════
# Traffic Checker — Ubuntu 22.04 VPS Setup Script
# Run as root: bash server_setup.sh
# ════════════════════════════════════════════════════════════════

set -e  # Stop on any error

echo ""
echo "════════════════════════════════════════"
echo "  Traffic Checker Server Setup"
echo "  Ubuntu 22.04 LTS"
echo "════════════════════════════════════════"
echo ""

# ── 1. System update ─────────────────────────────────────────
echo "[1/9] Updating system packages..."
apt-get update -q && apt-get upgrade -y -q

# ── 2. Core packages ─────────────────────────────────────────
echo "[2/9] Installing core packages..."
apt-get install -y -q \
    curl git unzip wget gnupg2 ca-certificates lsb-release \
    nginx supervisor redis-server \
    mysql-server mysql-client \
    python3 python3-pip python3-venv \
    xvfb libgbm-dev libnss3 libatk-bridge2.0-0 libdrm2 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libxss1 libasound2

# ── 3. PHP 8.3 ───────────────────────────────────────────────
echo "[3/9] Installing PHP 8.3..."
add-apt-repository ppa:ondrej/php -y -q
apt-get update -q
apt-get install -y -q \
    php8.3 php8.3-fpm php8.3-cli \
    php8.3-mysql php8.3-redis php8.3-xml \
    php8.3-curl php8.3-mbstring php8.3-zip php8.3-bcmath \
    php8.3-intl php8.3-gd

# Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
echo "   PHP $(php -r 'echo PHP_VERSION;') + Composer installed"

# ── 4. Node.js 20 ────────────────────────────────────────────
echo "[4/9] Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - -q
apt-get install -y -q nodejs
echo "   Node $(node -v) installed"

# ── 5. Playwright + Chromium ─────────────────────────────────
echo "[5/9] Installing Playwright + Chromium..."
pip3 install playwright -q
python3 -m playwright install chromium
python3 -m playwright install-deps chromium
# Also install via npm for the npx command
npm install -g playwright -q
echo "   Playwright + Chromium installed"

# ── 6. Xvfb virtual display ──────────────────────────────────
echo "[6/9] Configuring Xvfb virtual display..."
cat > /etc/systemd/system/xvfb.service << 'SERVICE'
[Unit]
Description=Xvfb Virtual Framebuffer
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable xvfb
systemctl start xvfb
echo "   Xvfb running on display :99"

# ── 7. MySQL ─────────────────────────────────────────────────
echo "[7/9] Configuring MySQL..."
DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
mysql -u root << SQL
CREATE DATABASE IF NOT EXISTS traffic_checker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'traffic_user'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON traffic_checker.* TO 'traffic_user'@'localhost';
FLUSH PRIVILEGES;
SQL
echo "   DB: traffic_checker | User: traffic_user | Pass: ${DB_PASS}"
echo "   ⚠  Save this password! Add to .env as DB_PASSWORD=${DB_PASS}"

# ── 8. Deploy user ───────────────────────────────────────────
echo "[8/9] Creating deploy user..."
if ! id "deploy" &>/dev/null; then
    adduser --disabled-password --gecos "" deploy
fi
usermod -aG www-data deploy
mkdir -p /var/www
chown deploy:deploy /var/www

# ── 9. Nginx ─────────────────────────────────────────────────
echo "[9/9] Configuring Nginx..."
cat > /etc/nginx/sites-available/traffic-checker << 'NGINX'
server {
    listen 80;
    server_name _;
    root /var/www/traffic-checker/public;
    index index.php;
    charset utf-8;
    client_max_body_size 10M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* { deny all; }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/traffic-checker /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# ── Supervisor (queue worker) ─────────────────────────────────
cat > /etc/supervisor/conf.d/traffic-queue.conf << 'CONF'
[program:traffic-queue]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/traffic-checker/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/supervisor/traffic-queue.log
stopwaitsecs=3600
CONF

supervisorctl reread && supervisorctl update

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  Server setup complete!"
echo ""
echo "  NEXT STEPS:"
echo "  1. Upload your app to /var/www/traffic-checker"
echo "  2. Copy traffic_checker.py to /var/www/"
echo "  3. cd /var/www/traffic-checker"
echo "  4. cp .env.example .env"
echo "  5. nano .env  ← fill in DB_PASSWORD=${DB_PASS} + other settings"
echo "  6. composer install --no-dev"
echo "  7. php artisan key:generate"
echo "  8. php artisan migrate --seed"
echo "  9. php artisan storage:link"
echo " 10. chown -R www-data:www-data storage bootstrap/cache"
echo " 11. (crontab -e) → * * * * * php /var/www/traffic-checker/artisan schedule:run"
echo ""
echo "  For SSL: certbot --nginx -d your-domain.com"
echo "════════════════════════════════════════════════════════"
