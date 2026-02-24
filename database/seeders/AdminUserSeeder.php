<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('users')->updateOrInsert(
            ['email' => env('FILAMENT_ADMIN_EMAIL', 'admin@example.com')],
            [
                'name'              => 'Admin',
                'email'             => env('FILAMENT_ADMIN_EMAIL', 'admin@example.com'),
                'password'          => Hash::make(env('FILAMENT_ADMIN_PASSWORD', 'change_me')),
                'email_verified_at' => now(),
                'created_at'        => now(),
                'updated_at'        => now(),
            ]
        );
    }
}
