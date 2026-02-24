#!/bin/bash
PHP="/opt/cpanel/ea-php83/root/usr/bin/php"
APP="/home/samirgroupnet/traffic-checker"

echo "Creating all missing Laravel files..."

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
echo "✓ artisan"

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
echo "✓ bootstrap/app.php"

# public/
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
echo "✓ public/index.php + .htaccess"

# App/Http/Kernel.php
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
        'auth'     => \Illuminate\Auth\Middleware\Authenticate::class,
        'guest'    => \Illuminate\Auth\Middleware\RedirectIfAuthenticated::class,
        'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'verified' => \Illuminate\Auth\Middleware\EnsureEmailIsVerified::class,
    ];
}
PHP
echo "✓ App/Http/Kernel.php"

# App/Exceptions/Handler.php
mkdir -p "$APP/app/Exceptions"
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
echo "✓ App/Exceptions/Handler.php"

# storage dirs
mkdir -p "$APP/storage/framework/"{sessions,views,cache/data}
mkdir -p "$APP/storage/logs"
touch "$APP/storage/logs/laravel.log"
echo "✓ storage directories"

# permissions
chown -R samirgroupnet:samirgroupnet "$APP"
chmod -R 755 "$APP"
chmod +x "$APP/artisan"
chmod -R 775 "$APP/storage"
chmod -R 775 "$APP/bootstrap/cache"
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
