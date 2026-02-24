<?php

namespace App\Mail;

use App\Models\Vehicle;
use App\Models\ViolationCheck;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class ViolationAlert extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public Vehicle        $vehicle,
        public ViolationCheck $check,
    ) {}

    public function envelope(): Envelope
    {
        $subject = $this->check->has_violations
            ? "⚠️ Traffic Violations Found — {$this->vehicle->plate} — {$this->check->grand_total} EGP"
            : "✅ No Violations — {$this->vehicle->plate}";

        return new Envelope(subject: $subject);
    }

    public function content(): Content
    {
        return new Content(view: 'emails.violation-alert');
    }
}
