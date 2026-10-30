<?php

namespace Database\Seeders;

use App\Models\Badge;
use Illuminate\Database\Seeder;

class BadgeSeeder extends Seeder
{
    public function run(): void
    {
        $badges = [
            ['code' => 'first_focus',  'name' => 'First Focus',      'description' => 'Finish your first qualifying focus session.', 'condition_type' => 'sessions_completed', 'threshold' => 1],
            ['code' => 'streak_3',     'name' => '3-Day Streak',     'description' => 'Earn XP 3 days in a row.',                    'condition_type' => 'streak',             'threshold' => 3],
            ['code' => 'streak_7',     'name' => '7-Day Streak',     'description' => 'Earn XP 7 days in a row.',                    'condition_type' => 'streak',             'threshold' => 7],
            ['code' => 'streak_30',    'name' => '30-Day Streak',    'description' => 'Earn XP 30 days in a row.',                   'condition_type' => 'streak',             'threshold' => 30],
            ['code' => 'task_starter', 'name' => 'Task Starter',     'description' => 'Complete 10 tasks.',                          'condition_type' => 'tasks_completed',    'threshold' => 10],
            ['code' => 'task_master',  'name' => 'Task Master',      'description' => 'Complete 50 tasks.',                          'condition_type' => 'tasks_completed',    'threshold' => 50],
            ['code' => 'focus_10h',    'name' => '10 Hours Focused', 'description' => 'Reach 600 minutes of qualifying focus time.', 'condition_type' => 'focus_minutes',      'threshold' => 600],
            ['code' => 'level_5',      'name' => 'Level 5',          'description' => 'Reach level 5.',                              'condition_type' => 'level',              'threshold' => 5],
        ];

        foreach ($badges as $badge) {
            Badge::updateOrCreate(
                ['code' => $badge['code']],
                $badge + ['icon' => $badge['code'], 'is_active' => true]
            );
        }
    }
}