<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\GamificationService;
use Illuminate\Http\Request;

class UserController extends Controller
{
    // GET /api/v1/admin/users?search=ana&status=active&page=1
    public function index(Request $request, GamificationService $game)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'in:active,inactive'],
        ]);

        $users = User::query()
            ->with('progress')
            ->when($filters['search'] ?? null, function ($q, $search) {
                $q->where(fn ($q) => $q
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%"));
            })
            ->when(($filters['status'] ?? null) === 'active', fn ($q) => $q->where('is_active', true))
            ->when(($filters['status'] ?? null) === 'inactive', fn ($q) => $q->where('is_active', false))
            ->orderByRaw("role = 'admin' desc")
            ->orderBy('name')
            ->paginate(20);

        return response()->json([
            'data' => $users->getCollection()->map(fn (User $user) => $this->row($user, $game)),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    // PATCH /api/v1/admin/users/{user}/status   { "is_active": false }
    public function updateStatus(Request $request, User $user, GamificationService $game)
    {
        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
        ]);

        if ($user->isAdmin()) {
            return response()->json(['message' => 'Administrator accounts cannot be deactivated here.'], 422);
        }

        $user->is_active = $data['is_active'];
        $user->save();

        // Signing out every device makes the deactivation take effect on the next request.
        if (! $user->is_active) {
            $user->tokens()->delete();
        }

        return response()->json(['data' => $this->row($user->load('progress'), $game)]);
    }

    private function row(User $user, GamificationService $game): array
    {
        $progress = $user->progress;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'course' => $user->course,
            'year_level' => $user->year_level,
            'is_active' => (bool) $user->is_active,
            'level' => (int) ($progress?->level ?? 1),
            'total_xp' => (int) ($progress?->total_xp ?? 0),
            'streak_days' => $progress ? $game->currentStreak($progress) : 0,
            'last_active_on' => $progress?->last_active_on?->toDateString(),
            'created_at' => $user->created_at,
        ];
    }
}
