<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FocusSession;
use App\Models\User;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class FocusSessionController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(
            $request->user()->focusSessions()
                ->orderByDesc('started_at')
                ->paginate(15)
        );
    }

    // Restore an active or paused timer when Flutter opens.
    public function active(Request $request)
    {
        $session = $request->user()->focusSessions()
            ->whereIn('status', ['active', 'paused'])
            ->latest('id')
            ->first();

        return response()->json(
            $session === null
                ? ['session' => null]
                : $this->snapshot($session, Carbon::now())
        );
    }

    // Start a new focus session.
    public function store(Request $request)
    {
        $data = $request->validate([
            'planned_minutes' => [
                'required',
                'integer',
                'between:1,180',
            ],
            'task_id' => ['nullable', 'integer'],
        ]);

        $result = DB::transaction(function () use ($request, $data) {
            $user = $this->lockedUser($request);

            // A student may have only one ongoing session.
            if ($user->focusSessions()
                ->whereIn('status', ['active', 'paused'])
                ->exists()) {
                abort(
                    409,
                    'Finish or cancel your existing focus session first.'
                );
            }

            if (isset($data['task_id'])) {
                $user->tasks()
                    ->whereKey($data['task_id'])
                    ->firstOrFail();
            }

            $now = Carbon::now();

            $session = $user->focusSessions()->create([
                'task_id' => $data['task_id'] ?? null,
                'started_at' => $now,
                'segment_started_at' => $now,
                'accumulated_seconds' => 0,
                'paused_at' => null,
                'ended_at' => null,
                'duration_minutes' => null,
                'planned_minutes' => $data['planned_minutes'],
                'status' => 'active',
            ]);

            return $this->snapshot($session, $now);
        }, 3);

        return response()->json($result, 201);
    }

    // Pause the timer and save actual active seconds.
    public function pause(Request $request, FocusSession $session)
    {
        return response()->json(
            DB::transaction(function () use ($request, $session) {
                $user = $this->lockedUser($request);
                $locked = $this->lockedSession($user, $session);

                if ($locked->status !== 'active') {
                    abort(
                        409,
                        'Only a running focus session can be paused.'
                    );
                }

                $now = Carbon::now();

                $locked->accumulated_seconds =
                    $this->elapsedSeconds($locked, $now);

                $locked->status = 'paused';
                $locked->paused_at = $now;
                $locked->segment_started_at = null;
                $locked->save();

                return $this->snapshot($locked, $now);
            }, 3)
        );
    }

    // Resume counting only from the new start time.
    public function resume(Request $request, FocusSession $session)
    {
        return response()->json(
            DB::transaction(function () use ($request, $session) {
                $user = $this->lockedUser($request);
                $locked = $this->lockedSession($user, $session);

                if ($locked->status !== 'paused') {
                    abort(
                        409,
                        'Only a paused focus session can be resumed.'
                    );
                }

                $now = Carbon::now();

                $locked->status = 'active';
                $locked->segment_started_at = $now;
                $locked->paused_at = null;
                $locked->save();

                return $this->snapshot($locked, $now);
            }, 3)
        );
    }

    // Finish once and award XP through the existing ledger.
    public function finish(Request $request, FocusSession $session)
    {
        $result = DB::transaction(function () use ($request, $session) {
            $user = $this->lockedUser($request);
            $locked = $this->lockedSession($user, $session);

            if (!in_array(
                $locked->status,
                ['active', 'paused'],
                true
            )) {
                abort(409, 'This session has already ended.');
            }

            $now = Carbon::now();

            $seconds = $this->elapsedSeconds($locked, $now);
            $minutes = intdiv($seconds, 60);

            // 1 XP per full minute, minimum 10 minutes,
            // maximum 60 XP.
            $requestedXp = $minutes < 10
                ? 0
                : min($minutes, 60);

            $progress = $user->progress()
                ->lockForUpdate()
                ->first();

            if ($progress === null) {
                $progress = $user->progress()->create([
                    'total_xp' => 0,
                    'level' => 1,
                    'current_streak' => 0,
                    'longest_streak' => 0,
                ]);
            }

            // Applies the same daily cap as task completion.
            $reward = GamificationService::awardXp(
                $user,
                $progress,
                'session',
                (int) $locked->getKey(),
                $requestedXp,
                $now
            );

            $locked->status = 'finished';
            $locked->ended_at = $now;
            $locked->duration_minutes = $minutes;
            $locked->accumulated_seconds = $seconds;
            $locked->segment_started_at = null;
            $locked->paused_at = null;
            $locked->save();

            return [
                'message' => 'Focus session finished.',
                'session' => $locked,
                'duration_minutes' => $minutes,
                'xp_earned' => $reward['xp_earned'],
                'xp_today' => $reward['xp_today'],
                'daily_xp_cap' => $reward['daily_xp_cap'],
                'total_xp' => (int) $progress->total_xp,
                'level' => (int) $progress->level,
                'streak_days' =>
                    (int) $progress->current_streak,
            ];
        }, 3);

        return response()->json($result);
    }

    // Cancelling or resetting never earns XP.
    public function cancel(Request $request, FocusSession $session)
    {
        return response()->json(
            DB::transaction(function () use ($request, $session) {
                $user = $this->lockedUser($request);
                $locked = $this->lockedSession($user, $session);

                if (!in_array(
                    $locked->status,
                    ['active', 'paused'],
                    true
                )) {
                    abort(
                        409,
                        'Only a running or paused session can be cancelled.'
                    );
                }

                $now = Carbon::now();

                $locked->status = 'cancelled';
                $locked->ended_at = $now;
                $locked->duration_minutes = 0;
                $locked->accumulated_seconds = 0;
                $locked->segment_started_at = null;
                $locked->paused_at = null;
                $locked->save();

                return [
                    'message' =>
                        'Focus session cancelled; no XP awarded.',
                    'session' => $locked,
                    'xp_earned' => 0,
                ];
            }, 3)
        );
    }

    private function lockedUser(Request $request): User
    {
        return User::query()
            ->whereKey($request->user()->getKey())
            ->lockForUpdate()
            ->firstOrFail();
    }

    private function lockedSession(
        User $user,
        FocusSession $session
    ): FocusSession {
        return $user->focusSessions()
            ->whereKey($session->getKey())
            ->lockForUpdate()
            ->firstOrFail();
    }

    // Counts only periods when the session was active.
    private function elapsedSeconds(
        FocusSession $session,
        Carbon $now
    ): int {
        $seconds = (int) (
            $session->accumulated_seconds ?? 0
        );

        if ($session->status === 'active') {
            $segmentStart =
                $session->segment_started_at
                ?? $session->started_at;

            if ($segmentStart !== null) {
                $seconds += max(
                    0,
                    (int) floor(
                        $segmentStart->diffInSeconds($now)
                    )
                );
            }
        }

        return min(
            $seconds,
            (int) $session->planned_minutes * 60
        );
    }

    private function snapshot(
        FocusSession $session,
        Carbon $now
    ): array {
        $elapsed = $this->elapsedSeconds($session, $now);
        $planned = (int) $session->planned_minutes * 60;

        return [
            'session' => $session,
            'elapsed_seconds' => $elapsed,
            'remaining_seconds' => max(
                0,
                $planned - $elapsed
            ),
        ];
    }
}
