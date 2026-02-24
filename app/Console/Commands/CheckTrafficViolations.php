<?php

namespace App\Console\Commands;

use App\Models\Vehicle;
use App\Services\NotificationService;
use App\Services\PlaywrightCheckerService;
use Illuminate\Console\Command;

class CheckTrafficViolations extends Command
{
    protected $signature   = 'traffic:check {--vehicle= : Check a specific vehicle ID} {--all : Check all active vehicles} {--notify : Send notifications after checking}';
    protected $description = 'Check traffic violations on ppo.gov.eg via Playwright';

    public function __construct(
        protected PlaywrightCheckerService $checker,
        protected NotificationService      $notifier,
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $vehicleId = $this->option('vehicle');
        $checkAll  = $this->option('all');
        $notify    = $this->option('notify');

        if ($vehicleId) {
            $vehicle = Vehicle::findOrFail($vehicleId);
            $this->checkOne($vehicle, $notify);
        } elseif ($checkAll) {
            $vehicles = Vehicle::where('is_active', true)->get();
            $this->info("Checking {$vehicles->count()} active vehicle(s)...");

            foreach ($vehicles as $vehicle) {
                $this->checkOne($vehicle, $notify);
            }
        } else {
            $this->error('Specify --vehicle=ID or --all');
            return self::FAILURE;
        }

        return self::SUCCESS;
    }

    protected function checkOne(Vehicle $vehicle, bool $notify): void
    {
        $this->line("\n🚗 Checking: {$vehicle->owner_name} | Plate: {$vehicle->plate}");

        $check = $this->checker->checkVehicle($vehicle);

        if ($check->status === 'error') {
            $this->error("   ❌ Error: {$check->error_message}");
            return;
        }

        if ($check->has_violations) {
            $this->warn("   ⚠️  {$check->violations_count} violation(s) — Total: {$check->grand_total} EGP");
        } else {
            $this->info('   ✅ No violations');
        }

        if ($notify) {
            $this->notifier->notify($check);
            $this->line('   📨 Notifications sent');
        }
    }
}
