<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\FocusSessionResource;
use App\Models\FocusSession;
use App\Models\User;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class FocusSessionController extends Controller
{
    // Longest session a student can plan.
    private const MAX_PLANNED_MINUTES = 180;

    // GET /api/v1/sessions?status=active
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status' => ['nullable', 'in:active,finished,cancelled'],
        ]);

        $sessions = $request->user()->focusSessions()
            ->with('task')
            ->when($filters['status'] ?? null, fn ($q, $status) => $q->where('status', $status))
            ->latest('started_at')
            ->latest('id')
            ->paginate(15);

        return FocusSessionResource::collection($sessions);
    }

    // POST /api/v1/sessions   { "task_id": 3, "planned_minutes": 25 }
    public function store(Request $request, GamificationService $game)
    {
        $user = $request->user();

        $data = $request->validate([
            'task_id' => [
                'nullable', 'integer',
                // the task must exist, belong to this student and still be pending
                Rule::exists('tasks', 'id')
                    ->where('user_id', $user->id)
                    ->where('status', 'pending'),
            ],
            'planned_minutes' => [
                'required', 'integer',
                'min:' . $game->setting('min_session_minutes'),
                'max:' . self::MAX_PLANNED_MINUTES,
            ],
        ]);

        return DB::transaction(function () use ($user, $data) {
            // Lock the user row so two quick taps cannot start two sessions.
            User::whereKey($user->id)->lockForUpdate()->first();

            $active = $user->focusSessions()->where('status', 'active')->with('task')->first();
            if ($active) {
                return response()->json([
                    'message' => 'You already have an active focus session.',
                    'active_session' => new FocusSessionResource($active),
                ], 409);
            }

            $session = $user->focusSessions()->create([
                'task_id' => $data['task_id'] ?? null,
                'planned_minutes' => $data['planned_minutes'],
                'started_at' => now(),
                'status' => 'active',
            ]);

            return (new FocusSessionResource($session->load('task')))
                ->response()
                ->setStatusCode(201);
        });
    }

    // PATCH /api/v1/sessions/{session}/finish   (no body: the server times it)
    public function finish(Request $request, int $session, GamificationService $game)
    {
        return DB::transaction(function () use ($request, $session, $game) {
            $user = $request->user();
            $focus = $this->lockOwnSession($user, $session);

            if ($focus->status !== 'active') {
                abort(409, 'This session has already ended.');
            }

            $minutes = $this->elapsedMinutes($focus);

            $focus->status = 'finished';
            $focus->ended_at = now();
            $focus->duration_minutes = $minutes;
            $focus->save();

            // Count at most the planned length and the per-session limit.
            $counted = min($minutes, $focus->planned_minutes, $game->setting('max_session_minutes'));
            $qualifies = $minutes >= $game->setting('min_session_minutes');
            $baseXp = $qualifies ? $counted * $game->setting('xp_per_minute') : 0;

            $reward = $qualifies
                ? $game->award($user, 'session', $focus->id, $baseXp)
                : ['xp_awarded' => 0, 'capped' => false, 'leveled_up' => false, 'evolved' => false, 'new_badges' => []];

            $progress = $game->snapshot($user->fresh());

            return response()->json([
                'data' => [
                    'session' => new FocusSessionResource($focus->load('task')),
                    'qualifies' => $qualifies,
                    'xp_awarded' => $reward['xp_awarded'],
                    'capped' => $reward['capped'],
                    'leveled_up' => $reward['leveled_up'],
                    'pet_evolved' => $reward['evolved'],
                    'new_badges' => $reward['new_badges'],
                    'progress' => $progress,
                ],
            ]);
        }, 3);
    }

    // PATCH /api/v1/sessions/{session}/cancel   (gives no XP)
    public function cancel(Request $request, int $session)
    {
        return DB::transaction(function () use ($request, $session) {
            $focus = $this->lockOwnSession($request->user(), $session);

            if ($focus->status !== 'active') {
                abort(409, 'This session has already ended.');
            }

            $focus->status = 'cancelled';
            $focus->ended_at = now();
            $focus->duration_minutes = $this->elapsedMinutes($focus);
            $focus->save();

            return new FocusSessionResource($focus->load('task'));
        });
    }

    // Another student's session answers 404, so its id is not revealed.
    private function lockOwnSession(User $user, int $id): FocusSession
    {
        return $user->focusSessions()->whereKey($id)->lockForUpdate()->firstOrFail();
    }

    // Whole minutes from the server's own timestamps; the client's timer is ignored.
    private function elapsedMinutes(FocusSession $focus): int
    {
        $seconds = max(0, $focus->started_at->diffInSeconds(now(), true));

        // Rounded, so a 25-minute timer that reaches zero counts as 25
        // even if the start request arrived a second late.
        return (int) round($seconds / 60);
    }
}
