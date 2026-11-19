<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\GamificationService;
use Illuminate\Http\Request;

class PetController extends Controller
{
    // GET /api/v1/pet
    public function show(Request $request, GamificationService $game)
    {
        return response()->json(['data' => $this->petData($request->user(), $game)]);
    }

    // PUT /api/v1/pet   { "name": "Mochi" }
    public function update(Request $request, GamificationService $game)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:1', 'max:50'],
        ]);

        $user = $request->user();
        $pet = $user->pet ?? $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);
        $pet->name = trim($data['name']);
        $pet->save();

        return response()->json(['data' => $this->petData($user->fresh(), $game)]);
    }

    private function petData(User $user, GamificationService $game): array
    {
        $progress = $game->snapshot($user);
        $level = $progress['level'];
        $nextLevel = GamificationService::nextStageLevel($level);

        $stages = array_map(fn ($stage) => $stage + [
            'reached' => $level >= $stage['min_level'],
        ], GamificationService::stages());

        $nextStage = collect($stages)->firstWhere('min_level', $nextLevel);

        return [
            'name' => $progress['pet_name'],
            'stage' => $progress['pet_stage'],
            'mood' => $progress['pet_mood'],
            'level' => $level,
            'next_stage' => $nextStage['stage'] ?? null,
            'next_stage_level' => $nextLevel,
            'stages' => $stages,
        ];
    }
}
