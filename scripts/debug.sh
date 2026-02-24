#!/bin/bash
PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"
cd "$APP"

echo "=== PHP version ==="
$PHP -v

echo ""
echo "=== artisan exists? ==="
ls -la "$APP/artisan"

echo ""
echo "=== vendor/autoload.php exists? ==="
ls -la "$APP/vendor/autoload.php" 2>/dev/null || echo "MISSING — composer install failed"

echo ""
echo "=== composer install output (full) ==="
$PHP /usr/local/bin/composer install --no-dev --no-interaction 2>&1 | tail -30

echo ""
echo "=== artisan directly ==="
$PHP "$APP/artisan" --version 2>&1

echo ""
echo "=== .env contents ==="
cat "$APP/.env"
