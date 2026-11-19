<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Badge;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class BadgeController extends Controller
{
    // What a badge condition can measure (see GamificationService::badgeValues).
    public const CONDITIONS = ['sessions_completed', 'streak', 'tasks_completed', 'focus_minutes', 'level'];

    // GET /api/v1/admin/badges
    public function index()
    {
        $badges = Badge::withCount('users')->orderBy('id')->get();

        return response()->json([
            'data' => $badges->map(fn (Badge $badge) => $this->row($badge)),
            'meta' => ['conditions' => self::CONDITIONS],
        ]);
    }

    // POST /api/v1/admin/badges
    public function store(Request $request)
    {
        $badge = Badge::create($this->validated($request));
        $badge->loadCount('users');

        return response()->json(['data' => $this->row($badge)], 201);
    }

    // PUT /api/v1/admin/badges/{badge}   (set is_active false to disable)
    public function update(Request $request, Badge $badge)
    {
        $badge->update($this->validated($request, $badge));
        $badge->loadCount('users');

        return response()->json(['data' => $this->row($badge)]);
    }

    private function validated(Request $request, ?Badge $badge = null): array
    {
        $data = $request->validate([
            'code' => [
                'required', 'string', 'max:50', 'alpha_dash',
                Rule::unique('badges', 'code')->ignore($badge?->id),
            ],
            'name' => ['required', 'string', 'max:100'],
            'description' => ['required', 'string', 'max:255'],
            'condition_type' => ['required', Rule::in(self::CONDITIONS)],
            'threshold' => ['required', 'integer', 'min:1', 'max:100000'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $data['icon'] = $data['code'];

        return $data;
    }

    private function row(Badge $badge): array
    {
        return [
            'id' => $badge->id,
            'code' => $badge->code,
            'name' => $badge->name,
            'description' => $badge->description,
            'condition_type' => $badge->condition_type,
            'threshold' => (int) $badge->threshold,
            'is_active' => (bool) $badge->is_active,
            'awarded_count' => (int) ($badge->users_count ?? 0),
        ];
    }
}
