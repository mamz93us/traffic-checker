<?php

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        //
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })
    ->withSchedule(function (Schedule $schedule) {
        $frequency = config('traffic.check_frequency', 'daily');
        $time1     = config('traffic.check_time_1', '08:00');
        $time2     = config('traffic.check_time_2', '20:00');

        $command = $schedule->command('traffic:check --all --notify')
            ->timezone('Africa/Cairo')
            ->withoutOverlapping()
            ->runInBackground()
            ->emailOutputOnFailure(config('mail.from.address'));

        match ($frequency) {
            'twice_daily' => $command->twiceDaily(
                (int) explode(':', $time1)[0],
                (int) explode(':', $time2)[0]
            ),
            'weekly'  => $command->weeklyOn(0, $time1),
            default   => $command->dailyAt($time1),
        };
    })
    ->create();
