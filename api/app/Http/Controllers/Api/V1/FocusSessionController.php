<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FocusSession;
use App\Services\GamificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FocusSessionController extends Controller
{
    private function shape(object $s): array
    {
        return [
            'id' => (int) $s->id,
            'task_id' => $s->task_id ? (int) $s->task_id : null,
            'status' => $s->status,
            'planned_minutes' => (int) $s->planned_minutes,
            'duration_minutes' => $s->duration_minutes !== null ? (int) $s->duration_minutes : null,
            'started_at' => Carbon::parse($s->started_at)->toIso8601String(),
            'ended_at' => $s->ended_at ? Carbon::parse($s->ended_at)->toIso8601String() : null,
        ];
    }

    // GET /api/v1/sessions?from=&to=
    public function index(Request $request)
    {
        $f = $request->validate([
            'from' => ['nullable', 'date'],
            'to'   => ['nullable', 'date'],
        ]);

        $page = DB::table('focus_sessions')
            ->where('user_id', $request->user()->id)
            ->when($f['from'] ?? null, fn ($q, $d) => $q->whereDate('started_at', '>=', $d))
            ->when($f['to'] ?? null, fn ($q, $d) => $q->whereDate('started_at', '<=', $d))
            ->orderByDesc('started_at')
            ->paginate(15);

        return response()->json([
            'data' => collect($page->items())->map(fn ($s) => $this->shape($s))->all(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    // POST /api/v1/sessions
    public function start(Request $request)
    {
        $data = $request->validate([
            'planned_minutes' => ['required', 'integer', 'min:10', 'max:180'],
            'task_id'         => ['nullable', 'integer'],
        ]);
        $userId = $request->user()->id;

        if (! empty($data['task_id'])) {
            $owner = DB::table('tasks')->where('id', $data['task_id'])->value('user_id');
            if ($owner === null) {
                return response()->json([
                    'message' => 'The selected task does not exist.',
                    'errors' => ['task_id' => ['The selected task does not exist.']],
                ], 422);
            }
            abort_unless((int) $owner === $userId, 403, 'This action is unauthorized.');
        }

        return DB::transaction(function () use ($data, $userId) {
            // Lock this user's progress row so two starts cannot both pass the check.
            DB::table('progress')->insertOrIgnore([
                'user_id' => $userId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('progress')->where('user_id', $userId)->lockForUpdate()->first();

            $active = DB::table('focus_sessions')
                ->where('user_id', $userId)->where('status', 'active')->exists();
            if ($active) {
                return response()->json(['message' => 'You already have an active session.'], 409);
            }

            $id = DB::table('focus_sessions')->insertGetId([
                'user_id' => $userId,
                'task_id' => $data['task_id'] ?? null,
                'started_at' => now(),
                'planned_minutes' => $data['planned_minutes'],
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $row = DB::table('focus_sessions')->where('id', $id)->first();
            return response()->json(['data' => $this->shape($row)], 201);
        });
    }

    // PATCH /api/v1/sessions/{session}/finish
    public function finish(Request $request, FocusSession $session, GamificationService $game)
    {
        abort_unless($session->user_id === $request->user()->id, 403, 'This action is unauthorized.');

        return DB::transaction(function () use ($session, $game) {
            $row = DB::table('focus_sessions')->where('id', $session->id)->lockForUpdate()->first();

            if ($row->status !== 'active') {
                return response()->json(['message' => 'This session has already ended.'], 409);
            }

            // The duration always comes from the server's clock, never from the app.
            $now = now();
            $minutes = (int) floor(abs(Carbon::parse($row->started_at)->diffInSeconds($now)) / 60);

            DB::table('focus_sessions')->where('id', $row->id)->update([
                'ended_at' => $now,
                'duration_minutes' => $minutes,
                'status' => 'finished',
                'updated_at' => $now,
            ]);

            $row = DB::table('focus_sessions')->where('id', $row->id)->first();

            return response()->json([
                'data' => array_merge(
                    ['session' => $this->shape($row)],
                    $game->awardForSession($row)
                ),
            ]);
        });
    }

    // PATCH /api/v1/sessions/{session}/cancel
    public function cancel(Request $request, FocusSession $session)
    {
        abort_unless($session->user_id === $request->user()->id, 403, 'This action is unauthorized.');

        return DB::transaction(function () use ($session) {
            $row = DB::table('focus_sessions')->where('id', $session->id)->lockForUpdate()->first();

            if ($row->status !== 'active') {
                return response()->json(['message' => 'This session has already ended.'], 409);
            }

            DB::table('focus_sessions')->where('id', $row->id)->update([
                'ended_at' => now(),
                'status' => 'cancelled',
                'updated_at' => now(),
            ]);

            $row = DB::table('focus_sessions')->where('id', $row->id)->first();
            return response()->json(['data' => $this->shape($row)]);
        });
    }
}