<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $email    = config('auth.admin_email', 'admin@example.com');
        $password = config('auth.admin_password', 'change_me');

        DB::table('users')->updateOrInsert(
            ['email' => $email],
            [
                'name'              => 'Admin',
                'email'             => $email,
                'password'          => Hash::make($password),
                'email_verified_at' => now(),
                'created_at'        => now(),
                'updated_at'        => now(),
            ]
        );
    }
}
