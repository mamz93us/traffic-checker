#!/bin/bash
# Fix missing PHP extensions + install Composer properly
# Run as ROOT

PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"

echo "=== Installing missing PHP 8.3 extensions via EasyApache ==="
# Install all extensions Laravel needs
dnf install -y \
    ea-php83-php-mbstring \
    ea-php83-php-xml \
    ea-php83-php-curl \
    ea-php83-php-zip \
    ea-php83-php-bcmath \
    ea-php83-php-mysqlnd \
    ea-php83-php-pdo \
    ea-php83-php-json \
    ea-php83-php-iconv \
    ea-php83-php-intl \
    ea-php83-php-gd \
    ea-php83-php-opcache \
    ea-php83-php-tokenizer \
    ea-php83-php-fileinfo \
    2>&1 | grep -E "^(Installing|Installed|Nothing|Complete|Error|✓|✗)" 

echo ""
echo "=== Verifying extensions ==="
for ext in mbstring xml curl zip bcmath pdo_mysql json iconv; do
    $PHP -m 2>/dev/null | grep -q "^$ext$" \
        && echo "  ✓ $ext" \
        || echo "  ✗ $ext STILL MISSING"
done

echo ""
echo "=== Installing Composer properly ==="
curl -sS https://getcomposer.org/installer | $PHP -- --install-dir=/usr/local/bin --filename=composer
echo "  ✓ Composer installed: $(/usr/local/bin/composer --version 2>/dev/null)"

echo ""
echo "=== Running composer install ==="
cd "$APP"
$PHP /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction 2>&1

echo ""
echo "=== Running artisan setup ==="
cd "$APP"
$PHP artisan key:generate --force    && echo "  ✓ key generated"   || echo "  ✗ key failed"
$PHP artisan migrate --force --seed  && echo "  ✓ migrated"        || echo "  ✗ migrate failed"
$PHP artisan config:cache            && echo "  ✓ config cached"   || echo "  ✗ config failed"
$PHP artisan route:cache             && echo "  ✓ routes cached"   || echo "  ✗ routes failed"
$PHP artisan view:cache              && echo "  ✓ views cached"    || echo "  ✗ views failed"
$PHP artisan storage:link 2>/dev/null; echo "  ✓ storage link"

echo ""
echo "=== Final test ==="
$PHP artisan --version && echo "  ✅ Laravel is working!" || echo "  ✗ Still failing"

echo ""
echo "=== Fix permissions ==="
chown -R samirgroupnet:samirgroupnet "$APP"
chmod -R 775 "$APP/storage" "$APP/bootstrap/cache"
chmod 755 "$APP/artisan"
echo "  ✓ Permissions set"

echo ""
echo "✅ Done! Visit https://t.samirgroup.net"
