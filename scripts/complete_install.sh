#!/bin/bash
# Run as ROOT — completes the Laravel installation
# ════════════════════════════════════════════════════════════════

PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"
USER="samirgroupnet"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Completing Laravel installation for traffic-checker     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

cd "$APP" || err "Cannot cd into $APP"

# ── 1. Create missing Laravel scaffold files ──────────────────
echo "[1/6] Creating missing Laravel files..."

# artisan
cat > "$APP/artisan" << 'PHP'
#!/usr/bin/env php
<?php
define('LARAVEL_START', microtime(true));
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$status = $kernel->handle(
    $input = new Symfony\Component\Console\Input\ArgvInput,
    new Symfony\Component\Console\Output\ConsoleOutput
);
$kernel->terminate($input, $status);
exit($status);
PHP
chmod +x "$APP/artisan"
ok "artisan created"

# bootstrap/
mkdir -p "$APP/bootstrap/cache"
cat > "$APP/bootstrap/app.php" << 'PHP'
<?php
$app = new Illuminate\Foundation\Application(
    $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
);
$app->singleton(
    Illuminate\Contracts\Http\Kernel::class,
    App\Http\Kernel::class
);
$app->singleton(
    Illuminate\Contracts\Console\Kernel::class,
    App\Console\Kernel::class
);
$app->singleton(
    Illuminate\Contracts\Debug\ExceptionHandler::class,
    App\Exceptions\Handler::class
);
return $app;
PHP
ok "bootstrap/app.php created"

# public/index.php
mkdir -p "$APP/public"
cat > "$APP/public/index.php" << 'PHP'
<?php
define('LARAVEL_START', microtime(true));
if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}
require __DIR__.'/../vendor/autoload.php';
$app = require_once __DIR__.'/../bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$response = $kernel->handle(
    $request = Illuminate\Http\Request::capture()
)->send();
$kernel->terminate($request, $response);
PHP
ok "public/index.php created"

# public/.htaccess
cat > "$APP/public/.htaccess" << 'HTACCESS'
<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>
    RewriteEngine On
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>
HTACCESS
ok "public/.htaccess created"

# App/Http/Kernel.php (required by bootstrap)
mkdir -p "$APP/app/Http"
cat > "$APP/app/Http/Kernel.php" << 'PHP'
<?php
namespace App\Http;
use Illuminate\Foundation\Http\Kernel as HttpKernel;
class Kernel extends HttpKernel
{
    protected $middleware = [
        \Illuminate\Http\Middleware\TrustProxies::class,
        \Illuminate\Http\Middleware\HandleCors::class,
        \Illuminate\Foundation\Http\Middleware\PreventRequestsDuringMaintenance::class,
        \Illuminate\Http\Middleware\ValidatePostSize::class,
        \Illuminate\Foundation\Http\Middleware\TrimStrings::class,
        \Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull::class,
    ];
    protected $middlewareGroups = [
        'web' => [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\View\Middleware\ShareErrorsFromSession::class,
            \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],
        'api' => [
            \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],
    ];
    protected $middlewareAliases = [
        'auth'       => \Illuminate\Auth\Middleware\Authenticate::class,
        'guest'      => \Illuminate\Auth\Middleware\RedirectIfAuthenticated::class,
        'throttle'   => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'verified'   => \Illuminate\Auth\Middleware\EnsureEmailIsVerified::class,
    ];
}
PHP
ok "App/Http/Kernel.php created"

# App/Exceptions/Handler.php
mkdir -p "$APP/app/Exceptions"
cat > "$APP/app/Exceptions/Handler.php" << 'PHP'
<?php
namespace App\Exceptions;
use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Throwable;
class Handler extends ExceptionHandler
{
    protected $dontFlash = ['current_password','password','password_confirmation'];
    public function register(): void {}
}
PHP
ok "App/Exceptions/Handler.php created"

# storage directories Laravel needs
mkdir -p "$APP/storage/framework/"{sessions,views,cache/data}
mkdir -p "$APP/storage/logs"
touch "$APP/storage/logs/laravel.log"
ok "storage directories created"

# ── 2. Composer install ───────────────────────────────────────
echo ""
echo "[2/6] Running composer install (2-3 minutes)..."
cd "$APP"
$PHP /usr/local/bin/composer install \
    --no-dev --optimize-autoloader --no-interaction 2>&1 \
    | grep -E "^(  -|Generating|Nothing|Loading)" | head -20
ok "Composer packages installed"

# ── 3. Laravel artisan setup ──────────────────────────────────
echo ""
echo "[3/6] Running Laravel artisan setup..."
cd "$APP"
$PHP artisan key:generate --force    && ok "App key generated"
$PHP artisan migrate --force --seed  && ok "Database migrated + admin user created"
$PHP artisan config:cache            && ok "Config cached"
$PHP artisan route:cache             && ok "Routes cached"
$PHP artisan view:cache              && ok "Views cached"
$PHP artisan storage:link 2>/dev/null || true
ok "Storage link created"

# ── 4. Fix subdomain bootstrap to use public/index.php ───────
echo ""
echo "[4/6] Updating subdomain bootstrap..."
SUBDOMAIN="/home/samirgroupnet/public_html/t.samirgroup.net"
mkdir -p "$SUBDOMAIN"

# Simple passthrough — loads Laravel's real public/index.php
cat > "$SUBDOMAIN/index.php" << 'PHP'
<?php
$pub = '/home/samirgroupnet/traffic-checker/public';
chdir($pub);
$_SERVER['DOCUMENT_ROOT'] = $pub;
require $pub . '/index.php';
PHP

cat > "$SUBDOMAIN/.htaccess" << 'HTACCESS'
Options -Indexes
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ /home/samirgroupnet/traffic-checker/public/$1 [L]
HTACCESS
ok "Subdomain bootstrap updated"

# ── 5. Permissions ────────────────────────────────────────────
echo ""
echo "[5/6] Setting permissions..."
chown -R "$USER:$USER" "$APP"
chown -R "$USER:$USER" "$SUBDOMAIN"
chmod -R 755 "$APP"
chmod 775 "$APP/artisan"
chmod -R 775 "$APP/storage"
chmod -R 775 "$APP/bootstrap/cache"
ok "Permissions set"

# ── 6. Verify ─────────────────────────────────────────────────
echo ""
echo "[6/6] Final verification..."
cd "$APP"
$PHP artisan --version && ok "Laravel is working!" || err "Still broken — paste error output"
echo ""
$PHP artisan migrate:status 2>/dev/null | head -8

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Installation complete!                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Visit: https://t.samirgroup.net                             ║"
echo "║                                                              ║"
echo "║  NOW edit .env (3 things):                                   ║"
echo "║  nano /home/samirgroupnet/traffic-checker/.env              ║"
echo "║                                                              ║"
echo "║  1. MAIL_PASSWORD=         ← cPanel email password           ║"
echo "║  2. WHATSAPP_INSTANCE_ID=  ← from green-api.com              ║"
echo "║     WHATSAPP_ACCESS_TOKEN=                                   ║"
echo "║  3. FILAMENT_ADMIN_PASSWORD= ← your chosen password          ║"
echo "║                                                              ║"
echo "║  Then run:                                                   ║"
echo "║  /opt/cpanel/ea-php83/root/usr/bin/php                      ║"
echo "║    /home/samirgroupnet/traffic-checker/artisan config:cache  ║"
echo "║                                                              ║"
echo "║  Login email: admin@samirgroup.net                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
