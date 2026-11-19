<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class SummaryController extends Controller
{
    // GET /api/v1/summary/weekly?week_of=2026-11-19   (any day of the week; default: this week)
    public function weekly(Request $request, GamificationService $game)
    {
        $data = $request->validate([
            'week_of' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $user = $request->user();
        $day = isset($data['week_of']) ? Carbon::parse($data['week_of']) : today();
        $start = $day->copy()->startOfWeek(Carbon::MONDAY)->startOfDay();
        $end = $start->copy()->addDays(6)->endOfDay();

        // Only sessions long enough to earn XP count as study time.
        $sessions = $user->focusSessions()
            ->with('task')
            ->where('status', 'finished')
            ->where('duration_minutes', '>=', $game->setting('min_session_minutes'))
            ->whereBetween('started_at', [$start, $end])
            ->orderBy('started_at')
            ->get();

        $tasks = $user->tasks()
            ->where('status', 'completed')
            ->whereBetween('completed_at', [$start, $end])
            ->orderBy('completed_at')
            ->get();

        $xpByDay = $user->xpLedger()
            ->whereBetween('earned_on', [$start->toDateString(), $end->toDateString()])
            ->get()
            ->groupBy(fn ($row) => $row->earned_on->toDateString())
            ->map(fn ($rows) => (int) $rows->sum('amount'));

        $days = [];
        for ($i = 0; $i < 7; $i++) {
            $date = $start->copy()->addDays($i);
            $key = $date->toDateString();
            $daySessions = $sessions->filter(fn ($s) => $s->started_at->toDateString() === $key);

            $days[] = [
                'date' => $key,
                'day' => $date->format('D'),       // Mon, Tue, ...
                'minutes' => (int) $daySessions->sum('duration_minutes'),
                'sessions' => $daySessions->count(),
                'tasks_completed' => $tasks->filter(fn ($t) => $t->completed_at->toDateString() === $key)->count(),
                'xp' => $xpByDay->get($key, 0),
            ];
        }

        $days = collect($days);

        return response()->json([
            'data' => [
                'start_date' => $start->toDateString(),
                'end_date' => $end->toDateString(),
                'days' => $days,
                'totals' => [
                    'minutes' => $days->sum('minutes'),
                    'sessions' => $days->sum('sessions'),
                    'tasks_completed' => $days->sum('tasks_completed'),
                    'xp' => $days->sum('xp'),
                ],
                'sessions' => $sessions->map(fn ($s) => [
                    'id' => $s->id,
                    'started_at' => $s->started_at,
                    'duration_minutes' => (int) $s->duration_minutes,
                    'task_title' => $s->task?->title,
                ])->values(),
                'tasks' => $tasks->map(fn ($t) => [
                    'id' => $t->id,
                    'title' => $t->title,
                    'completed_at' => $t->completed_at,
                ])->values(),
            ],
        ]);
    }
}
