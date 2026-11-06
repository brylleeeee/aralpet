<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use App\Models\User;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class TaskController extends Controller
{
    // GET /api/v1/tasks
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status' => [
                'nullable',
                'in:pending,completed',
            ],
            'subject_id' => [
                'nullable',
                'integer',
            ],
            'due' => [
                'nullable',
                'in:today,week,overdue',
            ],
        ]);

        $today = Carbon::today(
            GamificationService::TIMEZONE
        );

        $todayString = $today->toDateString();

        $tasks = $request->user()
            ->tasks()
            ->with('subject')
            ->when(
                $filters['status'] ?? null,
                fn ($q, $status) =>
                    $q->where('status', $status)
            )
            ->when(
                $filters['subject_id'] ?? null,
                fn ($q, $id) =>
                    $q->where('subject_id', $id)
            )
            ->when(
                ($filters['due'] ?? null) === 'today',
                fn ($q) => $q->whereDate(
                    'due_date',
                    $todayString
                )
            )
            ->when(
                ($filters['due'] ?? null) === 'week',
                fn ($q) => $q->whereBetween(
                    'due_date',
                    [
                        $todayString,
                        $today->copy()
                            ->endOfWeek()
                            ->toDateString(),
                    ]
                )
            )
            ->when(
                ($filters['due'] ?? null) === 'overdue',
                fn ($q) => $q
                    ->where('status', 'pending')
                    ->whereDate(
                        'due_date',
                        '<',
                        $todayString
                    )
            )
            ->orderByRaw(
                'due_date IS NULL, due_date'
            )
            ->latest('id')
            ->paginate(15);

        return TaskResource::collection($tasks);
    }

    // POST /api/v1/tasks
    public function store(StoreTaskRequest $request)
    {
        $task = $request->user()
            ->tasks()
            ->create($request->validated());

        $task->refresh()->load('subject');

        return (new TaskResource($task))
            ->response()
            ->setStatusCode(201);
    }

    // PUT /api/v1/tasks/{task}
    public function update(
        StoreTaskRequest $request,
        Task $task
    ) {
        $this->authorize('update', $task);

        if ($task->status === 'completed') {
            return response()->json([
                'message' =>
                    'Completed tasks cannot be edited.',
            ], 409);
        }

        $task->update($request->validated());

        return new TaskResource(
            $task->load('subject')
        );
    }

    // DELETE /api/v1/tasks/{task}
    public function destroy(Task $task)
    {
        $this->authorize('delete', $task);

        $task->delete();

        return response()->noContent();
    }

    // POST /api/v1/tasks/{task}/complete
    public function complete(
        Request $request,
        Task $task
    ) {
        // Existing ownership policy.
        $this->authorize('update', $task);

        $result = DB::transaction(
            function () use ($request, $task) {
                // Lock the user first.
                // This serializes XP updates for
                // this student's reward sources.
                $user = User::query()
                    ->whereKey(
                        $request->user()->getKey()
                    )
                    ->lockForUpdate()
                    ->firstOrFail();

                // Lock the task to prevent
                // simultaneous reward claims.
                $lockedTask = $user->tasks()
                    ->whereKey($task->getKey())
                    ->lockForUpdate()
                    ->firstOrFail();

                if (
                    $lockedTask->status ===
                    'completed'
                ) {
                    return [
                        'message' =>
                            'Task already completed.',
                        'already_completed' => true,
                        'xp_earned' => 0,
                        'task' => new TaskResource(
                            $lockedTask->load(
                                'subject'
                            )
                        ),
                    ];
                }

                if (
                    $lockedTask->status !==
                    'pending'
                ) {
                    abort(
                        409,
                        'Only pending tasks can be completed.'
                    );
                }

                // Find and lock progress.
                $progress = $user->progress()
                    ->lockForUpdate()
                    ->first();

                if ($progress === null) {
                    $progress = $user->progress()
                        ->create([
                            'total_xp' => 0,
                            'level' => 1,
                            'current_streak' => 0,
                            'longest_streak' => 0,
                        ]);
                }

                // Philippine completion time.
                $completedAt = Carbon::now(
                    GamificationService::TIMEZONE
                );

                $dueDate = $lockedTask->due_date
                    ? Carbon::parse(
                        $lockedTask->due_date
                    )->toDateString()
                    : null;

                // Calculate normal task reward.
                $requestedXp =
                    GamificationService::
                    taskCompletionXp(
                        $dueDate,
                        $completedAt->toDateString()
                    );

                // Record reward in XP ledger,
                // enforce daily limit, and
                // update progress and streaks.
                $reward =
                    GamificationService::awardXp(
                        $user,
                        $progress,
                        'task',
                        (int) $lockedTask->getKey(),
                        $requestedXp,
                        $completedAt
                    );

                // Mark task completed.
                $lockedTask->status = 'completed';
                $lockedTask->completed_at =
                    $completedAt;

                $lockedTask->save();

                // Return the actual XP awarded.
                return [
                    'message' =>
                        'Congratulations! Task completed.',

                    'already_completed' => false,

                    'xp_earned' =>
                        $reward['xp_earned'],

                    'xp_today' =>
                        $reward['xp_today'],

                    'daily_xp_cap' =>
                        $reward['daily_xp_cap'],

                    'total_xp' =>
                        (int) $progress->total_xp,

                    'level' =>
                        (int) $progress->level,

                    'streak_days' =>
                        (int) $progress->current_streak,

                    'task' => new TaskResource(
                        $lockedTask->load('subject')
                    ),
                ];
            },
            3
        );

        return response()->json($result);
    }
}
