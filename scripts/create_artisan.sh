#!/bin/bash
PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"
DOMAIN_ROOT="/home/samirgroupnet/public_html/t.samirgroup.net"

echo "Creating all missing Laravel files..."

# artisan — skip if already in git
if [ ! -f "$APP/artisan" ]; then
cat > "$APP/artisan" << 'PHP'
#!/usr/bin/env php
<?php
use Symfony\Component\Console\Input\ArgvInput;
define('LARAVEL_START', microtime(true));
require __DIR__.'/vendor/autoload.php';
$status = (require_once __DIR__.'/bootstrap/app.php')
    ->handleCommand(new ArgvInput);
exit($status);
PHP
chmod +x "$APP/artisan"
echo "✓ artisan (created)"
else
chmod +x "$APP/artisan"
echo "✓ artisan (already exists)"
fi

# bootstrap/ — skip app.php if already in git
mkdir -p "$APP/bootstrap/cache"
if [ ! -f "$APP/bootstrap/app.php" ]; then
echo "✗ bootstrap/app.php missing — run: git pull"
exit 1
else
echo "✓ bootstrap/app.php (already exists)"
fi

# public/ — skip index.php if already in git
mkdir -p "$APP/public"
if [ ! -f "$APP/public/index.php" ]; then
echo "✗ public/index.php missing — run: git pull"
exit 1
else
echo "✓ public/index.php (already exists)"
fi

if [ ! -f "$APP/public/.htaccess" ]; then
echo "✗ public/.htaccess missing — run: git pull"
exit 1
else
echo "✓ public/.htaccess (already exists)"
fi

# App/Http/Kernel.php — only needed for old-style bootstrap, skip for Laravel 11
echo "✓ App/Http/Kernel.php (not needed, Laravel 11 style)"

# App/Exceptions/Handler.php
mkdir -p "$APP/app/Exceptions"
if [ ! -f "$APP/app/Exceptions/Handler.php" ]; then
cat > "$APP/app/Exceptions/Handler.php" << 'PHP'
<?php
namespace App\Exceptions;
use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
class Handler extends ExceptionHandler
{
    protected $dontFlash = ['current_password','password','password_confirmation'];
    public function register(): void {}
}
PHP
echo "✓ App/Exceptions/Handler.php (created)"
else
echo "✓ App/Exceptions/Handler.php (already exists)"
fi

# storage dirs
mkdir -p "$APP/storage/framework/"{sessions,views,cache/data}
mkdir -p "$APP/storage/logs"
touch "$APP/storage/logs/laravel.log"
echo "✓ storage directories"

# cPanel domain bridge — routes t.samirgroup.net → traffic-checker/public
mkdir -p "$DOMAIN_ROOT"

cat > "$DOMAIN_ROOT/index.php" << 'PHP'
<?php
use Illuminate\Http\Request;
define('LARAVEL_START', microtime(true));
if (file_exists($maintenance = __DIR__.'/../../traffic-checker/storage/framework/maintenance.php')) {
    require $maintenance;
}
require __DIR__.'/../../traffic-checker/vendor/autoload.php';
(require_once __DIR__.'/../../traffic-checker/bootstrap/app.php')
    ->handleRequest(Request::capture());
PHP

cp "$APP/public/.htaccess" "$DOMAIN_ROOT/.htaccess"
echo "✓ cPanel domain bridge (public_html/t.samirgroup.net/)"

# permissions
chown -R samirgroupnet:samirgroupnet "$APP"
chmod -R 755 "$APP"
chmod +x "$APP/artisan"
chmod -R 775 "$APP/storage"
chmod -R 775 "$APP/bootstrap/cache"
chown -R samirgroupnet:samirgroupnet "$DOMAIN_ROOT"
chmod -R 755 "$DOMAIN_ROOT"
echo "✓ permissions"

echo ""
echo "=== Running artisan ==="
$PHP "$APP/artisan" key:generate --force   && echo "✓ key generated"  || echo "✗ key failed"
$PHP "$APP/artisan" migrate --force --seed && echo "✓ migrated"       || echo "✗ migrate failed"
$PHP "$APP/artisan" config:cache           && echo "✓ config cached"  || echo "✗ config failed"
$PHP "$APP/artisan" route:cache            && echo "✓ routes cached"  || echo "✗ routes failed"
$PHP "$APP/artisan" view:cache             && echo "✓ views cached"   || echo "✗ views failed"
$PHP "$APP/artisan" storage:link 2>/dev/null; echo "✓ storage:link"

echo ""
echo "=== Final test ==="
$PHP "$APP/artisan" --version && echo "" && echo "✅ Laravel is working! Visit https://t.samirgroup.net" || echo "✗ still failing"
