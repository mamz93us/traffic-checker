<?php

namespace App\Services;

use App\Models\Vehicle;
use App\Models\ViolationCheck;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;
use Symfony\Component\Process\Exception\ProcessTimedOutException;

/**
 * PlaywrightCheckerService
 *
 * Runs scripts/checker_wrapper.py as a subprocess.
 * Laravel passes vehicle JSON via stdin → Python outputs result JSON to stdout.
 *
 * Architecture:
 *   Laravel (PHP) handles DB, scheduling, dashboard, notifications
 *   Python/Playwright handles browser automation + ppo.gov.eg scraping
 */
class PlaywrightCheckerService
{
    protected string $pythonBin;
    protected string $wrapperScript;
    protected int    $timeout;

    public function __construct()
    {
        $this->pythonBin     = config('traffic.python_bin',    '/usr/bin/python3');
        $this->wrapperScript = base_path('scripts/checker_wrapper.py');
        $this->timeout       = (int) config('traffic.check_timeout', 180);
    }

    /**
     * Check one vehicle. Creates and returns a ViolationCheck record.
     */
    public function checkVehicle(Vehicle $vehicle): ViolationCheck
    {
        $check = ViolationCheck::create([
            'vehicle_id' => $vehicle->id,
            'checked_at' => now(),
            'status'     => 'pending',
        ]);

        try {
            $result = $this->runPythonScript($vehicle);
            $screenshotPath = $this->storeScreenshot($vehicle, $result);

            $check->update([
                'status'            => 'success',
                'has_violations'    => $result['has_violations']  ?? false,
                'violations_count'  => count($result['violations'] ?? []),
                'fines_total'       => (float) ($result['fines']         ?? 0),
                'court_fees'        => (float) ($result['court_fees']    ?? 0),
                'service_fees'      => (float) ($result['service_fees']  ?? 0),
                'appeal_fees'       => (float) ($result['appeal_fees']   ?? 0),
                'postal_fees'       => (float) ($result['postal_fees']   ?? 0),
                'grand_total'       => (float) ($result['grand_total']   ?? 0),
                'owner_name'        => $result['owner_name']      ?? null,
                'license_number'    => $result['license_number']  ?? null,
                'violations_json'   => $result['violations']      ?? [],
                'screenshot_path'   => $screenshotPath,
                'error_message'     => null,
            ]);

        } catch (\Exception $e) {
            Log::error("Playwright check failed for vehicle #{$vehicle->id} ({$vehicle->plate}): {$e->getMessage()}");
            $check->update([
                'status'        => 'error',
                'error_message' => $this->sanitizeText($e->getMessage()),
            ]);
        }

        return $check->fresh();
    }

    /**
     * Check all active vehicles sequentially (used by Artisan command).
     */
    public function checkAll(): array
    {
        $vehicles = Vehicle::where('is_active', true)->get();
        $results  = [];

        foreach ($vehicles as $vehicle) {
            $results[] = $this->checkVehicle($vehicle);
            // Be polite to the server between checks
            sleep(3);
        }

        return $results;
    }

    // ────────────────────────────────────────────────────────────
    //  PRIVATE
    // ────────────────────────────────────────────────────────────

    protected function runPythonScript(Vehicle $vehicle): array
    {
        if (!file_exists($this->wrapperScript)) {
            throw new \RuntimeException(
                "Wrapper script not found: {$this->wrapperScript}\n" .
                "Make sure scripts/checker_wrapper.py is deployed."
            );
        }

        $screenshotDir = storage_path('app/screenshots');
        @mkdir($screenshotDir, 0755, true);

        $vehicleJson = json_encode([
            'owner'       => $vehicle->owner_name,
            'letter_1'    => $vehicle->letter_1,
            'letter_2'    => $vehicle->letter_2,
            'letter_3'    => $vehicle->letter_3 ?? '',
            'numbers'     => $vehicle->plate_numbers,
            'national_id' => $vehicle->national_id,
            'phone'       => $vehicle->phone,
            'output_dir'  => $screenshotDir,
        ], JSON_UNESCAPED_UNICODE);

        $process = new Process(
            [$this->pythonBin, $this->wrapperScript],
            base_path(),                              // working directory
            ['DISPLAY' => ':99', 'HOME' => '/root']  // Xvfb display + home
        );

        $process->setInput($vehicleJson);
        $process->setTimeout($this->timeout);

        Log::info("Starting Playwright check for: {$vehicle->plate}");

        try {
            $process->run();
        } catch (ProcessTimedOutException $e) {
            throw new \RuntimeException("Timeout after {$this->timeout}s for vehicle {$vehicle->plate}");
        }

        // Exit code 1 = "has violations" (Python sys.exit(1) when violations found) — still valid
        // Exit code > 1 = real error
        if (!$process->isSuccessful() && $process->getExitCode() > 1) {
            $stderr = trim($process->getErrorOutput());
            throw new \RuntimeException("Python error (exit {$process->getExitCode()}): {$stderr}");
        }

        $stdout = trim($process->getOutput());
        if (empty($stdout)) {
            throw new \RuntimeException("No output from Python script. Stderr: " . $process->getErrorOutput());
        }

        // traffic_checker.py may print non-JSON lines to stdout before the result.
        // Find the last line that is valid JSON.
        $result = null;
        foreach (array_reverse(explode("\n", $stdout)) as $line) {
            $line = trim($line);
            if (empty($line)) continue;
            $decoded = json_decode($line, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $result = $decoded;
                break;
            }
        }

        if ($result === null) {
            throw new \RuntimeException("No JSON found in Python output: " . substr($stdout, 0, 200));
        }

        if (isset($result['error']) && !empty($result['error'])) {
            throw new \RuntimeException("Python script error: {$result['error']}");
        }

        Log::info("Check complete for {$vehicle->plate}: " .
            ($result['has_violations'] ? "⚠️ {$result['grand_total']} EGP" : "✅ clean"));

        return $result;
    }

    /** Strip non-ASCII/non-printable chars so MySQL latin1/utf8 columns don't reject the value. */
    protected function sanitizeText(string $text): string
    {
        return mb_convert_encoding(
            preg_replace('/[^\x09\x0A\x0D\x20-\x7E]/u', '?', $text),
            'UTF-8', 'UTF-8'
        );
    }

    protected function storeScreenshot(Vehicle $vehicle, array $result): ?string
    {
        $src = $result['screenshot_path'] ?? null;
        if (!$src || !file_exists($src)) {
            return null;
        }

        $relativePath = "screenshots/vehicle_{$vehicle->id}/" . basename($src);

        Storage::disk('local')->put($relativePath, file_get_contents($src));
        @unlink($src);

        return $relativePath;
    }
}
