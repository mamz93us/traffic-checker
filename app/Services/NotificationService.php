<?php

namespace App\Services;

use App\Mail\ViolationAlert;
use App\Models\Vehicle;
use App\Models\ViolationCheck;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class NotificationService
{
    public function __construct(
        protected WhatsAppService $whatsApp
    ) {}

    /**
     * Send all applicable notifications for a completed check.
     * Only sends if the check has violations (or if $forceAll = true).
     */
    public function notify(ViolationCheck $check, bool $forceAll = false): void
    {
        $vehicle = $check->vehicle;

        if (!$check->has_violations && !$forceAll) {
            Log::info("No violations for {$vehicle->plate} — skipping notifications");
            return;
        }

        // Email
        if ($vehicle->notify_email && $vehicle->email) {
            $this->sendEmail($vehicle, $check);
        }

        // WhatsApp
        if ($vehicle->notify_whatsapp) {
            $this->whatsApp->sendViolationAlert($vehicle, $check);
        }
    }

    protected function sendEmail(Vehicle $vehicle, ViolationCheck $check): void
    {
        try {
            Mail::to($vehicle->email)
                ->send(new ViolationAlert($vehicle, $check));

            $check->update(['notified_email' => true]);
            Log::info("Email sent to {$vehicle->email} for {$vehicle->plate}");
        } catch (\Exception $e) {
            Log::error("Email failed for {$vehicle->plate}: {$e->getMessage()}");
        }
    }
}
