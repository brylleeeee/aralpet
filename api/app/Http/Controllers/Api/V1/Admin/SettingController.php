<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\GamificationService;
use Illuminate\Http\Request;

class SettingController extends Controller
{
    // The XP rules an administrator may change, with their limits.
    private const RULES = [
        'daily_xp_cap'        => ['label' => 'Daily XP cap', 'min' => 10, 'max' => 5000],
        'min_session_minutes' => ['label' => 'Minimum session length (minutes)', 'min' => 1, 'max' => 60],
        'max_session_minutes' => ['label' => 'Most minutes counted per session', 'min' => 10, 'max' => 180],
        'xp_per_minute'       => ['label' => 'XP per focus minute', 'min' => 1, 'max' => 10],
        'task_xp'             => ['label' => 'XP per completed task', 'min' => 0, 'max' => 500],
        'task_on_time_bonus'  => ['label' => 'On-time task bonus XP', 'min' => 0, 'max' => 500],
    ];

    // GET /api/v1/admin/settings
    public function index(GamificationService $game)
    {
        return response()->json(['data' => $this->rows($game)]);
    }

    // PUT /api/v1/admin/settings   { "daily_xp_cap": 400, "task_xp": 20 }
    public function update(Request $request, GamificationService $game)
    {
        $rules = [];
        foreach (self::RULES as $key => $rule) {
            $rules[$key] = ['sometimes', 'integer', "min:{$rule['min']}", "max:{$rule['max']}"];
        }
        $data = $request->validate($rules);

        // The minimum session must not be longer than the most minutes counted.
        $min = $data['min_session_minutes'] ?? $game->setting('min_session_minutes');
        $max = $data['max_session_minutes'] ?? $game->setting('max_session_minutes');
        if ($min > $max) {
            return response()->json([
                'message' => 'The minimum session length cannot be more than the most minutes counted.',
                'errors' => ['min_session_minutes' => ['Must not be more than the most minutes counted.']],
            ], 422);
        }

        foreach ($data as $key => $value) {
            Setting::updateOrCreate(['key' => $key], ['value' => (string) $value]);
        }

        return response()->json(['data' => $this->rows($game)]);
    }

    private function rows(GamificationService $game): array
    {
        $rows = [];
        foreach (self::RULES as $key => $rule) {
            $rows[] = $rule + ['key' => $key, 'value' => $game->setting($key)];
        }

        return $rows;
    }
}
