<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Badge;
use App\Services\GamificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class BadgeController extends Controller
{
    // GET /api/v1/badges   Earned badges first, then locked ones with progress.
    public function index(Request $request, GamificationService $game)
    {
        $user = $request->user();
        $earned = $user->badges()->get()->keyBy('id');

        $progress = $user->progress;
        $values = $game->badgeValues(
            $user,
            $progress ? $game->currentStreak($progress) : 0,
            (int) ($progress?->level ?? 1),
        );

        // Active badges, plus any earned badge the admin has since disabled.
        $badges = Badge::where('is_active', true)
            ->orWhereIn('id', $earned->keys())
            ->orderBy('id')
            ->get()
            ->map(function (Badge $badge) use ($earned, $values) {
                $awarded = $earned->get($badge->id);

                return [
                    'id' => $badge->id,
                    'code' => $badge->code,
                    'name' => $badge->name,
                    'description' => $badge->description,
                    'icon' => $badge->icon,
                    'condition_type' => $badge->condition_type,
                    'threshold' => (int) $badge->threshold,
                    'current' => min((int) ($values[$badge->condition_type] ?? 0), (int) $badge->threshold),
                    'earned' => $awarded !== null,
                    'awarded_at' => $awarded ? Carbon::parse($awarded->pivot->awarded_at)->toJSON() : null,
                ];
            })
            ->sortByDesc('earned')
            ->values();

        return response()->json([
            'data' => $badges,
            'meta' => [
                'earned' => $badges->where('earned', true)->count(),
                'total' => $badges->count(),
            ],
        ]);
    }
}
