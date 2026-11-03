<?php
namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class ProgressController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();

        $progress = $user->progress;
        $pet = $user->pet;

        $totalXp = (int) ($progress?->total_xp ?? 0);

        // Progressive XP system
        $level = 1;
        $xpRequired = 100;
        $remainingXp = $totalXp;

        while ($remainingXp >= $xpRequired) {
            $remainingXp -= $xpRequired;
            $level++;
            $xpRequired += 50;
        }

        // Philippine date
        $today = today()->toDateString();

        // Completed focus minutes today
        $minutesToday = $user->focusSessions()
            ->where('status', 'finished')
            ->whereDate('started_at', $today)
            ->sum('duration_minutes');

        // Pending tasks due today
        $tasksDueToday = $user->tasks()
            ->where('status', 'pending')
            ->whereDate('due_date', $today)
            ->count();

        return response()->json([
            'user_name' => $user->name,
            'level' => $level,
            'total_xp' => $totalXp,
            'xp_into_level' => $remainingXp,
            'xp_for_next_level' => $xpRequired,
            'streak_days' => (int) ($progress?->current_streak ?? 0),
            'minutes_today' => (int) $minutesToday,
            'tasks_due_today' => (int) $tasksDueToday,
            'pet_name' => $pet?->name ?? 'Aral',
            'pet_stage' => $pet?->stage ?? 'egg',
            'pet_mood' => 'happy',
        ]);
    }
}
