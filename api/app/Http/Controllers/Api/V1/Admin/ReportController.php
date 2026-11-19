<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\FocusSession;
use App\Models\Task;
use App\Models\User;
use App\Models\UserBadge;
use App\Models\XpLedger;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReportController extends Controller
{
    // GET /api/v1/admin/reports?period=week&date=2026-11-19
    // Totals for all students; no single student's data is shown.
    public function index(Request $request, GamificationService $game)
    {
        $data = $request->validate([
            'period' => ['nullable', 'in:week,month'],
            'date' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $period = $data['period'] ?? 'week';
        $day = isset($data['date']) ? Carbon::parse($data['date']) : today();

        if ($period === 'month') {
            $start = $day->copy()->startOfMonth();
            $end = $day->copy()->endOfMonth();
        } else {
            $start = $day->copy()->startOfWeek(Carbon::MONDAY)->startOfDay();
            $end = $start->copy()->addDays(6)->endOfDay();
        }

        $sessions = FocusSession::query()
            ->where('status', 'finished')
            ->where('duration_minutes', '>=', $game->setting('min_session_minutes'))
            ->whereBetween('started_at', [$start, $end]);

        $ledger = XpLedger::query()
            ->whereBetween('earned_on', [$start->toDateString(), $end->toDateString()]);

        $badges = UserBadge::query()
            ->whereBetween('awarded_at', [$start, $end])
            ->with('badge')
            ->get()
            ->groupBy(fn ($row) => $row->badge?->name ?? 'Unknown')
            ->map(fn ($rows, $name) => ['name' => $name, 'count' => $rows->count()])
            ->sortByDesc('count')
            ->values();

        return response()->json([
            'data' => [
                'period' => $period,
                'start_date' => $start->toDateString(),
                'end_date' => $end->toDateString(),
                'total_students' => User::where('role', 'student')->count(),
                'new_students' => User::where('role', 'student')->whereBetween('created_at', [$start, $end])->count(),
                // A student is active in the period if they earned XP in it.
                'active_students' => (clone $ledger)->distinct()->count('user_id'),
                'sessions' => (clone $sessions)->count(),
                'total_minutes' => (int) (clone $sessions)->sum('duration_minutes'),
                'tasks_completed' => Task::where('status', 'completed')
                    ->whereBetween('completed_at', [$start, $end])->count(),
                'xp_awarded' => (int) (clone $ledger)->sum('amount'),
                'badges_awarded' => $badges->sum('count'),
                'badges' => $badges,
            ],
        ]);
    }
}
