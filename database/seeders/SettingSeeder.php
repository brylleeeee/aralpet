<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

class SettingSeeder extends Seeder
{
    public function run(): void
    {
        $settings = [
            'daily_xp_cap'        => '300',  // max XP per Manila calendar day
            'min_session_minutes' => '10',   // shorter sessions earn 0 XP
            'max_session_minutes' => '60',   // most minutes counted per session
            'xp_per_minute'       => '1',
            'task_xp'             => '10',
            'task_on_time_bonus'  => '5',    // extra XP if completed by the due date
        ];

        foreach ($settings as $key => $value) {
            Setting::updateOrCreate(['key' => $key], ['value' => $value]);
        }
    }
}