<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TaskController extends Controller
{
    private const COMPLETION_XP = 50;

    // GET /api/v1/tasks
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status' => ['nullable', 'in:pending,completed'],
            'subject_id' => ['nullable', 'integer'],
            'due' => ['nullable', 'in:today,week,overdue'],
        ]);

        $today = today()->toDateString();

        $tasks = $request->user()->tasks()
            ->with('subject')
            ->when(
                $filters['status'] ?? null,
                fn ($q, $status) => $q->where('status', $status)
            )
            ->when(
                $filters['subject_id'] ?? null,
                fn ($q, $id) => $q->where('subject_id', $id)
            )
            ->when(
                ($filters['due'] ?? null) === 'today',
                fn ($q) => $q->whereDate('due_date', $today)
            )
            ->when(
                ($filters['due'] ?? null) === 'week',
                fn ($q) => $q->whereBetween('due_date', [
                    $today,
                    today()->endOfWeek()->toDateString(),
                ])
            )
            ->when(
                ($filters['due'] ?? null) === 'overdue',
                fn ($q) => $q
                    ->where('status', 'pending')
                    ->whereDate('due_date', '<', $today)
            )
            ->orderByRaw('due_date IS NULL, due_date')
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
    public function update(StoreTaskRequest $request, Task $task)
    {
        $this->authorize('update', $task);

        if ($task->status === 'completed') {
            return response()->json([
                'message' => 'Completed tasks cannot be edited.',
            ], 409);
        }

        $task->update($request->validated());

        return new TaskResource($task->load('subject'));
    }

    // DELETE /api/v1/tasks/{task}
    public function destroy(Task $task)
    {
        $this->authorize('delete', $task);

        $task->delete();

        return response()->noContent();
    }

    // POST /api/v1/tasks/{task}/complete
    public function complete(Request $request, Task $task)
    {
        // Use the existing task ownership policy.
        $this->authorize('update', $task);

        $result = DB::transaction(function () use ($request, $task) {
            $user = $request->user();

            // Lock the task to prevent simultaneous reward claims.
            $lockedTask = $user->tasks()
                ->whereKey($task->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            // A task can only earn XP once.
            if ($lockedTask->status === 'completed') {
                return [
                    'message' => 'Task already completed.',
                    'already_completed' => true,
                    'xp_earned' => 0,
                    'task' => new TaskResource(
                        $lockedTask->load('subject')
                    ),
                ];
            }

            if ($lockedTask->status !== 'pending') {
                abort(409, 'Only pending tasks can be completed.');
            }

            // Find and lock the user's progress.
            $progress = $user->progress()
                ->lockForUpdate()
                ->first();

            // Create progress if this account has no record yet.
            if ($progress === null) {
                $progress = $user->progress()->create([
                    'total_xp' => 0,
                    'level' => 1,
                    'current_streak' => 0,
                    'longest_streak' => 0,
                ]);
            }

            // Mark the task as completed.
            $lockedTask->status = 'completed';
            $lockedTask->completed_at = now();
            $lockedTask->save();

            // Award XP.
            $earnedXp = self::COMPLETION_XP;
            $totalXp = (int) $progress->total_xp + $earnedXp;

            // Recalculate level using the same formula
            // as ProgressController.
            $level = 1;
            $xpRequired = 100;
            $remainingXp = $totalXp;

            while ($remainingXp >= $xpRequired) {
                $remainingXp -= $xpRequired;
                $level++;
                $xpRequired += 50;
            }

            $progress->total_xp = $totalXp;
            $progress->level = $level;
            $progress->save();

            return [
                'message' => 'Congratulations! Task completed.',
                'already_completed' => false,
                'xp_earned' => $earnedXp,
                'total_xp' => $totalXp,
                'level' => $level,
                'task' => new TaskResource(
                    $lockedTask->load('subject')
                ),
            ];
        }, 3);

        return response()->json($result);
    }
}
