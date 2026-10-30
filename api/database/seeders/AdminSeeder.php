<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $email = env('ADMIN_EMAIL');
        $password = env('ADMIN_PASSWORD');

        if (! $email || ! $password) {
            $this->command->error('Set ADMIN_EMAIL and ADMIN_PASSWORD in .env first.');
            return;
        }

        $admin = User::firstOrNew(['email' => $email]);
        $admin->name = 'Administrator';
        $admin->password = $password;   // hashed automatically by the User model
        $admin->role = 'admin';
        $admin->is_active = true;
        $admin->save();
    }
}