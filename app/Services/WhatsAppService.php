<?php

namespace App\Services;

use App\Models\Vehicle;
use App\Models\ViolationCheck;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * WhatsAppService
 *
 * Supports two providers:
 *   green_api  — https://green-api.com  (free tier: 2000 msgs/month)
 *   twilio     — Twilio WhatsApp sandbox / Business API
 *
 * Set WHATSAPP_PROVIDER in .env to choose.
 */
class WhatsAppService
{
    protected string $provider;

    public function __construct()
    {
        $this->provider = config('traffic.whatsapp_provider', 'green_api');
    }

    /**
     * Send violation notification for a check result.
     */
    public function sendViolationAlert(Vehicle $vehicle, ViolationCheck $check): bool
    {
        if (!$vehicle->notify_whatsapp) {
            return false;
        }

        $to      = $this->normalizePhone($vehicle->whatsapp_target);
        $message = $this->buildMessage($vehicle, $check);

        $sent = match ($this->provider) {
            'twilio'    => $this->sendViaTwilio($to, $message),
            'green_api' => $this->sendViaGreenApi($to, $message),
            default     => false,
        };

        if ($sent) {
            $check->update(['notified_whatsapp' => true]);
            Log::info("WhatsApp sent to {$to} for vehicle {$vehicle->plate}");
        }

        return $sent;
    }

    // ─────────────────────────────────────────────────────────────
    //  MESSAGE BUILDER
    // ─────────────────────────────────────────────────────────────

    protected function buildMessage(Vehicle $vehicle, ViolationCheck $check): string
    {
        if (!$check->has_violations) {
            return
                "✅ *Traffic Violations Check*\n\n" .
                "Vehicle: *{$vehicle->owner_name}*\n" .
                "Plate:   *{$vehicle->plate}*\n\n" .
                "✅ No violations found!\n\n" .
                "_Checked: " . $check->checked_at->format('d/m/Y H:i') . "_";
        }

        $lines   = [];
        $lines[] = "⚠️ *Traffic Violations Alert!*";
        $lines[] = "";
        $lines[] = "🚗 *Vehicle:* {$vehicle->owner_name}";
        $lines[] = "🔢 *Plate:*   {$vehicle->plate}";
        if ($check->owner_name) {
            $lines[] = "👤 *Owner:*   {$check->owner_name}";
        }
        $lines[] = "";
        $lines[] = "💰 *Fee Summary:*";
        $lines[] = "   Total Fines:   {$check->fines_total} EGP";
        $lines[] = "   Court Fees:    {$check->court_fees} EGP";
        $lines[] = "   Service Fees:  {$check->service_fees} EGP";
        $lines[] = "   ─────────────────────";
        $lines[] = "   *GRAND TOTAL:  {$check->grand_total} EGP*";
        $lines[] = "";
        $lines[] = "📋 *Violations ({$check->violations_count} total):*";

        foreach (array_slice($check->violations, 0, 5) as $i => $v) {
            $lines[] = "";
            $lines[] = "*[" . ($i + 1) . "]* " . ($v['date'] ?? '—');
            $lines[] = "   📍 " . ($v['location']    ?? '—');
            $lines[] = "   ⚠️  " . ($v['description']  ?? '—');
            $lines[] = "   💵 " . ($v['fine_amount']  ?? '—') . " EGP";
        }

        if ($check->violations_count > 5) {
            $lines[] = "";
            $lines[] = "_... and " . ($check->violations_count - 5) . " more violations_";
        }

        $lines[] = "";
        $lines[] = "🌐 View full report: " . config('app.url') . "/violations/{$check->id}";
        $lines[] = "";
        $lines[] = "_Checked: " . $check->checked_at->format('d/m/Y H:i') . "_";

        return implode("\n", $lines);
    }

    // ─────────────────────────────────────────────────────────────
    //  GREEN API  (https://green-api.com — free 2000 msgs/month)
    // ─────────────────────────────────────────────────────────────

    protected function sendViaGreenApi(string $phone, string $message): bool
    {
        $instanceId   = config('traffic.whatsapp_instance_id');
        $accessToken  = config('traffic.whatsapp_access_token');

        if (!$instanceId || !$accessToken) {
            Log::warning('Green API credentials not configured');
            return false;
        }

        $url = "https://api.green-api.com/waInstance{$instanceId}/sendMessage/{$accessToken}";

        $response = Http::post($url, [
            'chatId'  => $phone . '@c.us',   // Green API format: 201234567890@c.us
            'message' => $message,
        ]);

        if ($response->successful()) {
            return true;
        }

        Log::error('Green API error: ' . $response->body());
        return false;
    }

    // ─────────────────────────────────────────────────────────────
    //  TWILIO  (https://twilio.com)
    // ─────────────────────────────────────────────────────────────

    protected function sendViaTwilio(string $phone, string $message): bool
    {
        $sid   = config('traffic.twilio_account_sid');
        $token = config('traffic.twilio_auth_token');
        $from  = config('traffic.twilio_whatsapp_from', 'whatsapp:+14155238886');

        if (!$sid || !$token) {
            Log::warning('Twilio credentials not configured');
            return false;
        }

        $url = "https://api.twilio.com/2010-04-01/Accounts/{$sid}/Messages.json";

        $response = Http::withBasicAuth($sid, $token)->asForm()->post($url, [
            'From' => $from,
            'To'   => "whatsapp:{$phone}",
            'Body' => $message,
        ]);

        if ($response->successful()) {
            return true;
        }

        Log::error('Twilio error: ' . $response->body());
        return false;
    }

    // ─────────────────────────────────────────────────────────────
    //  HELPERS
    // ─────────────────────────────────────────────────────────────

    /**
     * Normalize an Egyptian phone number to international format.
     * 01226655110 → 201226655110
     */
    protected function normalizePhone(string $phone): string
    {
        $phone = preg_replace('/\D/', '', $phone);

        if (str_starts_with($phone, '0') && strlen($phone) === 11) {
            $phone = '20' . substr($phone, 1); // 011... → 2011...
        }

        if (!str_starts_with($phone, '20')) {
            $phone = '20' . $phone;
        }

        return $phone;
    }
}
