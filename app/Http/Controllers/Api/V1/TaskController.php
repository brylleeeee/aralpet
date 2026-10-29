<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTaskRequest;
use App\Http\Resources\TaskResource;
use App\Models\Task;
use Illuminate\Http\Request;

class TaskController extends Controller
{
    // GET /api/v1/tasks?status=&subject_id=&due=today|week|overdue&page=
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status'     => ['nullable', 'in:pending,completed'],
            'subject_id' => ['nullable', 'integer'],
            'due'        => ['nullable', 'in:today,week,overdue'],
        ]);

        $today = today()->toDateString();

        $tasks = $request->user()->tasks()
            ->with('subject')
            ->when($filters['status'] ?? null, fn ($q, $status) => $q->where('status', $status))
            ->when($filters['subject_id'] ?? null, fn ($q, $id) => $q->where('subject_id', $id))
            ->when(($filters['due'] ?? null) === 'today', fn ($q) => $q->whereDate('due_date', $today))
            ->when(($filters['due'] ?? null) === 'week', fn ($q) => $q->whereBetween('due_date', [
                $today, today()->endOfWeek()->toDateString(),
            ]))
            ->when(($filters['due'] ?? null) === 'overdue', fn ($q) => $q
                ->where('status', 'pending')
                ->whereDate('due_date', '<', $today))
            ->orderByRaw('due_date IS NULL, due_date')   // tasks without a due date go last
            ->latest('id')
            ->paginate(15);

        return TaskResource::collection($tasks);
    }

    // POST /api/v1/tasks
    public function store(StoreTaskRequest $request)
    {
        $task = $request->user()->tasks()->create($request->validated());
        $task->refresh()->load('subject');   // load defaults like status = pending

        return (new TaskResource($task))->response()->setStatusCode(201);
    }

    // PUT /api/v1/tasks/{task}
    public function update(StoreTaskRequest $request, Task $task)
    {
        $this->authorize('update', $task);

        if ($task->status === 'completed') {
            return response()->json(['message' => 'Completed tasks cannot be edited.'], 409);
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
}