<?php
// database/migrations/2024_01_01_000002_create_violation_checks_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('violation_checks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained()->cascadeOnDelete();
            $table->timestamp('checked_at')->nullable();
            $table->string('status', 20)->default('pending'); // pending | success | error
            $table->boolean('has_violations')->default(false);
            $table->unsignedSmallInteger('violations_count')->default(0);
            $table->decimal('fines_total',   10, 2)->default(0);
            $table->decimal('court_fees',    10, 2)->default(0);
            $table->decimal('service_fees',  10, 2)->default(0);
            $table->decimal('appeal_fees',   10, 2)->default(0);
            $table->decimal('postal_fees',   10, 2)->default(0);
            $table->decimal('grand_total',   10, 2)->default(0);
            $table->string('owner_name')->nullable();
            $table->string('license_number')->nullable();
            $table->json('violations_json')->nullable();   // full violation array
            $table->string('screenshot_path')->nullable();
            $table->boolean('notified_email')->default(false);
            $table->boolean('notified_whatsapp')->default(false);
            $table->text('error_message')->nullable();
            $table->timestamps();

            $table->index(['vehicle_id', 'checked_at']);
            $table->index('has_violations');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('violation_checks');
    }
};
