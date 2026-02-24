<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule): void
    {
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
            'weekly'      => $command->weeklyOn(0, $time1), // Sunday
            default       => $command->dailyAt($time1),
        };
    }

    protected function commands(): void
    {
        $this->load(__DIR__ . '/Commands');
        require base_path('routes/console.php');
    }
}
