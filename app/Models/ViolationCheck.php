<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ViolationCheck extends Model
{
    protected $fillable = [
        'vehicle_id', 'checked_at', 'has_violations', 'violations_count',
        'fines_total', 'court_fees', 'service_fees', 'appeal_fees',
        'postal_fees', 'grand_total', 'owner_name', 'license_number',
        'violations_json', 'screenshot_path', 'notified_email',
        'notified_whatsapp', 'error_message', 'status',
    ];

    protected $casts = [
        'checked_at'        => 'datetime',
        'has_violations'    => 'boolean',
        'violations_json'   => 'array',
        'notified_email'    => 'boolean',
        'notified_whatsapp' => 'boolean',
        'fines_total'       => 'decimal:2',
        'court_fees'        => 'decimal:2',
        'service_fees'      => 'decimal:2',
        'appeal_fees'       => 'decimal:2',
        'postal_fees'       => 'decimal:2',
        'grand_total'       => 'decimal:2',
    ];

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function getViolationsAttribute(): array
    {
        return $this->violations_json ?? [];
    }

    /** Scope: latest check per vehicle (for dashboard stats) */
    public static function latestPerVehicle(): Builder
    {
        return static::whereIn('id', function ($query) {
            $query->selectRaw('MAX(id)')
                  ->from('violation_checks')
                  ->where('status', 'success')
                  ->groupBy('vehicle_id');
        });
    }
}
