<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Vehicle extends Model
{
    protected $fillable = [
        'owner_name',
        'letter_1',
        'letter_2',
        'letter_3',
        'plate_numbers',
        'national_id',
        'phone',
        'email',
        'whatsapp_number',
        'notify_email',
        'notify_whatsapp',
        'is_active',
        'notes',
    ];

    protected $casts = [
        'notify_email'     => 'boolean',
        'notify_whatsapp'  => 'boolean',
        'is_active'        => 'boolean',
    ];

    public function checks(): HasMany
    {
        return $this->hasMany(ViolationCheck::class);
    }

    public function latestCheck()
    {
        return $this->hasOne(ViolationCheck::class)->latestOfMany();
    }

    /** Full plate string for display, e.g. "لط 3112" */
    public function getPlateAttribute(): string
    {
        return trim($this->letter_1 . $this->letter_2 . $this->letter_3)
             . ' ' . $this->plate_numbers;
    }

    /** WhatsApp number to notify — falls back to phone */
    public function getWhatsappTargetAttribute(): string
    {
        return $this->whatsapp_number ?: $this->phone;
    }
}
