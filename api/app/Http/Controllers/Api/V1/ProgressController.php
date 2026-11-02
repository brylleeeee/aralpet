<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GamificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProgressController extends Controller
{
    // GET /api/v1/progress
    public function show(Request $request)
    {
        $user = $request->user();
        $now = Carbon::now('Asia/Manila');
        $today = $now->toDateString();
        $yesterday = $now->copy()->subDay()->toDateString();

        DB::table('progress')->insertOrIgnore([
            'user_id' => $user->id, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $p = DB::table('progress')->where('user_id', $user->id)->first();
        $pet = DB::table('pets')->where('user_id', $user->id)->first();

        $level = (int) $p->level;
        $totalXp = (int) $p->total_xp;
        $levelStart = GamificationService::xpForLevel($level);
        $levelEnd = GamificationService::xpForLevel($level + 1);

        // A streak that was not continued yesterday or today has already ended.
        $last = $p->last_active_on ? substr((string) $p->last_active_on, 0, 10) : null;
        $streak = in_array($last, [$today, $yesterday], true) ? (int) $p->current_streak : 0;

        // Today in Manila, converted to the time zone the database uses.
        $from = $now->copy()->startOfDay()->setTimezone(config('app.timezone'));
        $to = $now->copy()->endOfDay()->setTimezone(config('app.timezone'));

        $minutesToday = (int) DB::table('focus_sessions')
            ->where('user_id', $user->id)->where('status', 'finished')
            ->whereBetween('started_at', [$from, $to])->sum('duration_minutes');

        $tasksDueToday = DB::table('tasks')
            ->where('user_id', $user->id)->where('status', 'pending')
            ->whereDate('due_date', $today)->count();

        $xpToday = (int) DB::table('xp_ledger')
            ->where('user_id', $user->id)->where('earned_on', $today)->sum('amount');
        $cap = (int) (DB::table('settings')->where('key', 'daily_xp_cap')->value('value') ?? 300);

        return response()->json(['data' => [
            'user_name' => $user->name,
            'level' => $level,
            'total_xp' => $totalXp,
            'xp_into_level' => $totalXp - $levelStart,
            'xp_for_next_level' => $levelEnd - $levelStart,
            'streak_days' => $streak,
            'longest_streak' => (int) $p->longest_streak,
            'minutes_today' => $minutesToday,
            'tasks_due_today' => $tasksDueToday,
            'xp_today' => $xpToday,
            'daily_cap' => $cap,
            'pet_name' => $pet->name ?? 'Aral',
            'pet_stage' => $pet->stage ?? 'egg',
            'pet_mood' => PetController::mood($last),
        ]]);
    }
}