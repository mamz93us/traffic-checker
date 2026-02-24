#!/bin/bash
PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"

echo "=== Finding Composer ==="
COMPOSER=$(which composer 2>/dev/null)
[ -z "$COMPOSER" ] && COMPOSER=$(find /usr /opt /root /home -name "composer" -o -name "composer.phar" 2>/dev/null | grep -v vendor | head -1)
echo "Found: $COMPOSER"

# If still not found, download it now
if [ -z "$COMPOSER" ]; then
    echo "Downloading Composer..."
    curl -sS https://getcomposer.org/installer | $PHP -- --install-dir=/usr/local/bin --filename=composer
    COMPOSER="/usr/local/bin/composer"
    echo "Installed: $COMPOSER"
fi

echo ""
echo "=== Running composer install ==="
cd "$APP"
$PHP "$COMPOSER" install --no-dev --optimize-autoloader --no-interaction 2>&1

echo ""
echo "=== Running artisan setup ==="
cd "$APP"
$PHP artisan key:generate --force     && echo "✓ key generated"     || echo "✗ key failed"
$PHP artisan migrate --force --seed   && echo "✓ migrated"          || echo "✗ migrate failed"
$PHP artisan config:cache             && echo "✓ config cached"     || echo "✗ config failed"
$PHP artisan route:cache              && echo "✓ routes cached"     || echo "✗ routes failed"
$PHP artisan view:cache               && echo "✓ views cached"      || echo "✗ views failed"
$PHP artisan storage:link 2>/dev/null; echo "✓ storage link done"

echo ""
echo "=== Final test ==="
$PHP artisan --version

echo ""
echo "=== Fix permissions ==="
chown -R samirgroupnet:samirgroupnet "$APP"
chmod -R 775 "$APP/storage" "$APP/bootstrap/cache"
echo "✓ done"

echo ""
echo "✅ Visit https://t.samirgroup.net to check the site"
