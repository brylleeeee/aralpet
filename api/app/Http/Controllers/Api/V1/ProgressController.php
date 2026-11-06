<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GamificationService;
use App\Services\PetEvolutionService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use App\Services\PetMoodService;

class ProgressController extends Controller
{
    // GET /api/v1/progress
    public function show(Request $request)
    {
        $user = $request->user();

        $progress = $user->progress;
        $pet = $user->pet;

        $totalXp = (int) (
            $progress?->total_xp ?? 0
        );

        // Calculate student level.
        $level = GamificationService::levelForTotalXp(
            $totalXp
        );

        // Calculate pet stage from current level.
        $petStage = PetEvolutionService::stageForLevel(
            $level
        );

        // Philippine dates.
        $today = Carbon::today(
            GamificationService::TIMEZONE
        )->toDateString();

        $yesterday = Carbon::parse(
            $today,
            GamificationService::TIMEZONE
        )->subDay()->toDateString();

        // Completed study minutes today.
        $minutesToday = $user->focusSessions()
            ->where('status', 'finished')
            ->whereDate('started_at', $today)
            ->sum('duration_minutes');

        // Pending tasks due today.
        $tasksDueToday = $user->tasks()
            ->where('status', 'pending')
            ->whereDate('due_date', $today)
            ->count();

        // Current streak.
        $streakDays = (int) (
            $progress?->current_streak ?? 0
        );

        $lastActive = $progress?->last_active_on
            ? Carbon::parse(
                $progress->last_active_on,
                GamificationService::TIMEZONE
            )->toDateString()
            : null;

        // A missed full day resets the displayed streak.
        if (
            $lastActive !== $today &&
            $lastActive !== $yesterday
        ) {
            $streakDays = 0;
        }

        return response()->json([
            'user_name' => $user->name,

            // Student progress.
            'level' => $level,
            'total_xp' => $totalXp,

            'xp_into_level' =>
                GamificationService::xpIntoLevel(
                    $totalXp
                ),

            'xp_for_next_level' =>
                GamificationService::xpForNextLevel(
                    $totalXp
                ),

            // Study statistics.
            'streak_days' => $streakDays,
            'minutes_today' => (int) $minutesToday,
            'tasks_due_today' => (int) $tasksDueToday,

            // Pet information.
            'pet_name' => $pet?->name ?? 'Aral',
            'pet_stage' => $petStage,

            // Mood will be implemented separately.
            'pet_mood' => PetMoodService::forProgress($progress),

            // XP earned today.
            'xp_today' =>
                GamificationService::xpEarnedToday(
                    (int) $user->getKey(),
                    $today
                ),

            // Daily XP limit.
            'daily_xp_cap' =>
                GamificationService::dailyXpCap(),
        ]);
    }
}
