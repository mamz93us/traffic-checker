<?php
// database/migrations/2024_01_01_000001_create_vehicles_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('vehicles', function (Blueprint $table) {
            $table->id();
            $table->string('owner_name');
            $table->string('letter_1', 2);
            $table->string('letter_2', 2);
            $table->string('letter_3', 2)->nullable();
            $table->string('plate_numbers', 4);
            $table->string('national_id', 14);
            $table->string('phone', 15);
            $table->string('email')->nullable();
            $table->string('whatsapp_number', 15)->nullable();
            $table->boolean('notify_email')->default(true);
            $table->boolean('notify_whatsapp')->default(true);
            $table->boolean('is_active')->default(true);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vehicles');
    }
};
