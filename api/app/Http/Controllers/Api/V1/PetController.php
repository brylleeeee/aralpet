<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GamificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PetController extends Controller
{
    // happy = XP earned today, okay = yesterday, sleepy = two or more days ago.
    public static function mood(?string $lastActiveOn): string
    {
        $now = Carbon::now('Asia/Manila');
        $last = $lastActiveOn ? substr($lastActiveOn, 0, 10) : null;

        if ($last === $now->toDateString()) return 'happy';
        if ($last === $now->copy()->subDay()->toDateString()) return 'okay';
        return 'sleepy';
    }

    private function shape(int $userId): array
    {
        $pet = DB::table('pets')->where('user_id', $userId)->first();
        $progress = DB::table('progress')->where('user_id', $userId)->first();
        $level = (int) ($progress->level ?? 1);

        $next = collect([2, 5, 10, 20])->first(fn ($l) => $l > $level);

        return [
            'name' => $pet->name ?? 'Aral',
            'stage' => $pet->stage ?? GamificationService::stageForLevel($level),
            'mood' => self::mood($progress->last_active_on ?? null),
            'level' => $level,
            'next_evolution_level' => $next,           // null once the pet is an elder
            'xp_to_next_evolution' => $next
                ? max(0, GamificationService::xpForLevel($next) - (int) ($progress->total_xp ?? 0))
                : null,
        ];
    }

    // GET /api/v1/pet
    public function show(Request $request)
    {
        return response()->json(['data' => $this->shape($request->user()->id)]);
    }

    // PATCH /api/v1/pet
    public function update(Request $request)
    {
        $data = $request->validate(['name' => ['required', 'string', 'min:1', 'max:50']]);
        $userId = $request->user()->id;

        DB::table('pets')->where('user_id', $userId)
            ->update(['name' => trim($data['name']), 'updated_at' => now()]);

        return response()->json(['data' => $this->shape($userId)]);
    }
}