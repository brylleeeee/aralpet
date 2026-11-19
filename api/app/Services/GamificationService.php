<?php

namespace App\Services;

use App\Models\Badge;
use App\Models\Progress;
use App\Models\Setting;
use App\Models\User;
use App\Models\XpLedger;
use Illuminate\Support\Carbon;

/**
 * All reward rules live here, so tasks and focus sessions follow the same logic:
 * XP ledger (no double XP), daily cap, level, streak, pet stage and badges.
 *
 * award() must be called inside a DB::transaction().
 */
class GamificationService
{
    // Default values, used when a setting is missing from the settings table.
    private const DEFAULTS = [
        'daily_xp_cap'        => 300,
        'min_session_minutes' => 10,
        'max_session_minutes' => 60,
        'xp_per_minute'       => 1,
        'task_xp'             => 10,
        'task_on_time_bonus'  => 5,
    ];

    // Lowest level needed for each pet stage, highest first.
    private const PET_STAGES = [
        20 => 'elder',
        10 => 'adult',
        5  => 'junior',
        2  => 'hatchling',
        1  => 'egg',
    ];

    // Read a numeric rule from the settings table (admin can change these).
    public function setting(string $key): int
    {
        return (int) Setting::get($key, self::DEFAULTS[$key] ?? 0);
    }

    /**
     * Level from total XP. Level 2 needs 100 XP, and each level after
     * needs 50 XP more than the one before (100, 150, 200, ...).
     */
    public static function levelFor(int $totalXp): array
    {
        $level = 1;
        $xpRequired = 100;
        $remainingXp = $totalXp;

        while ($remainingXp >= $xpRequired) {
            $remainingXp -= $xpRequired;
            $level++;
            $xpRequired += 50;
        }

        return [
            'level' => $level,
            'xp_into_level' => $remainingXp,
            'xp_for_next_level' => $xpRequired,
        ];
    }

    public static function stageFor(int $level): string
    {
        foreach (self::PET_STAGES as $minLevel => $stage) {
            if ($level >= $minLevel) {
                return $stage;
            }
        }

        return 'egg';
    }

    // Lowest level of the next stage, or null at the last stage.
    public static function nextStageLevel(int $level): ?int
    {
        $next = null;
        foreach (self::PET_STAGES as $minLevel => $stage) {
            if ($minLevel > $level) {
                $next = $minLevel;
            }
        }

        return $next;
    }

    /**
     * Give XP for one source (a task or a session), once only.
     *
     * $baseXp is what the activity is worth before the daily cap.
     * Returns what was actually given and what changed.
     */
    public function award(User $user, string $sourceType, int $sourceId, int $baseXp): array
    {
        $progress = $this->lockProgress($user);
        $pet = $user->pet()->lockForUpdate()->first()
            ?? $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);

        $today = today();
        $oldLevel = (int) $progress->level;
        $oldStage = $pet->stage;

        // Daily cap: only give what is left for today.
        $earnedToday = (int) $user->xpLedger()
            ->whereDate('earned_on', $today)
            ->sum('amount');
        $leftToday = max(0, $this->setting('daily_xp_cap') - $earnedToday);
        $xp = min($baseXp, $leftToday);

        // The unique key on (source_type, source_id) blocks double XP.
        $user->xpLedger()->create([
            'source_type' => $sourceType,
            'source_id' => $sourceId,
            'amount' => $xp,
            'earned_on' => $today->toDateString(),
        ]);

        // A day counts toward the streak when the student earns XP that day.
        if ($baseXp > 0) {
            $this->updateStreak($progress, $today);
        }

        $progress->total_xp = (int) $progress->total_xp + $xp;
        $progress->level = self::levelFor($progress->total_xp)['level'];
        $progress->save();

        // The pet only grows; it never goes back a stage.
        $newStage = self::stageFor($progress->level);
        if ($this->stageRank($newStage) > $this->stageRank($oldStage)) {
            $pet->stage = $newStage;
            $pet->save();
        }

        $user->setRelation('progress', $progress);
        $user->setRelation('pet', $pet);

        return [
            'xp_awarded' => $xp,
            'capped' => $xp < $baseXp,
            'leveled_up' => $progress->level > $oldLevel,
            'evolved' => $pet->stage !== $oldStage,
            'new_badges' => $this->awardBadges($user, $progress),
        ];
    }

    // Progress shown on the dashboard and pet screen.
    public function snapshot(User $user): array
    {
        $progress = $user->progress ?? new Progress([
            'total_xp' => 0, 'level' => 1, 'current_streak' => 0, 'longest_streak' => 0,
        ]);
        $pet = $user->pet;

        $totalXp = (int) $progress->total_xp;
        $levelInfo = self::levelFor($totalXp);
        $today = today();

        $minutesToday = (int) $user->focusSessions()
            ->where('status', 'finished')
            ->whereDate('started_at', $today)
            ->sum('duration_minutes');

        $tasksDueToday = $user->tasks()
            ->where('status', 'pending')
            ->whereDate('due_date', $today)
            ->count();

        $xpToday = (int) $user->xpLedger()
            ->whereDate('earned_on', $today)
            ->sum('amount');

        return [
            'user_name' => $user->name,
            'level' => $levelInfo['level'],
            'total_xp' => $totalXp,
            'xp_into_level' => $levelInfo['xp_into_level'],
            'xp_for_next_level' => $levelInfo['xp_for_next_level'],
            'xp_today' => $xpToday,
            'daily_cap' => $this->setting('daily_xp_cap'),
            'streak_days' => $this->currentStreak($progress),
            'longest_streak' => (int) $progress->longest_streak,
            'minutes_today' => $minutesToday,
            'tasks_due_today' => $tasksDueToday,
            'pet_name' => $pet?->name ?? 'Aral',
            'pet_stage' => $pet?->stage ?? 'egg',
            'pet_mood' => $this->mood($progress),
            'next_stage_level' => self::nextStageLevel($levelInfo['level']),
        ];
    }

    // Streak still counts today if the last active day was today or yesterday.
    public function currentStreak(Progress $progress): int
    {
        $last = $progress->last_active_on;
        if ($last === null || $last->lt(today()->subDay())) {
            return 0;
        }

        return (int) $progress->current_streak;
    }

    // Happy if XP was earned today, okay if yesterday, sleepy after that.
    public function mood(Progress $progress): string
    {
        $last = $progress->last_active_on;
        if ($last === null) {
            return 'okay';
        }
        if ($last->isSameDay(today())) {
            return 'happy';
        }
        if ($last->isSameDay(today()->subDay())) {
            return 'okay';
        }

        return 'sleepy';
    }

    /**
     * The student's current value for each badge condition type,
     * e.g. ['streak' => 4, 'tasks_completed' => 12, ...].
     */
    public function badgeValues(User $user, int $streak, int $level): array
    {
        $minMinutes = $this->setting('min_session_minutes');
        $qualifyingSessions = $user->focusSessions()
            ->where('status', 'finished')
            ->where('duration_minutes', '>=', $minMinutes);

        return [
            'streak' => $streak,
            'level' => $level,
            'tasks_completed' => $user->tasks()->where('status', 'completed')->count(),
            'sessions_completed' => (clone $qualifyingSessions)->count(),
            'focus_minutes' => (int) (clone $qualifyingSessions)->sum('duration_minutes'),
        ];
    }

    // Every pet stage with the level it starts at, lowest first.
    public static function stages(): array
    {
        $stages = [];
        foreach (array_reverse(self::PET_STAGES, true) as $minLevel => $stage) {
            $stages[] = ['stage' => $stage, 'min_level' => $minLevel];
        }

        return $stages;
    }

    private function lockProgress(User $user): Progress
    {
        return $user->progress()->lockForUpdate()->first()
            ?? $user->progress()->create([
                'total_xp' => 0,
                'level' => 1,
                'current_streak' => 0,
                'longest_streak' => 0,
            ]);
    }

    private function updateStreak(Progress $progress, Carbon $today): void
    {
        $last = $progress->last_active_on;

        if ($last !== null && $last->isSameDay($today)) {
            return; // already counted today
        }

        if ($last !== null && $last->isSameDay($today->copy()->subDay())) {
            $progress->current_streak = (int) $progress->current_streak + 1;
        } else {
            $progress->current_streak = 1; // first day, or the streak was broken
        }

        $progress->longest_streak = max((int) $progress->longest_streak, $progress->current_streak);
        $progress->last_active_on = $today->toDateString();
    }

    private function stageRank(?string $stage): int
    {
        $rank = array_search($stage, array_reverse(array_values(self::PET_STAGES)), true);

        return $rank === false ? 0 : $rank;
    }

    // Give every active badge whose condition is now met. Returns the new ones.
    private function awardBadges(User $user, Progress $progress): array
    {
        $earnedIds = $user->badges()->pluck('badges.id');
        $badges = Badge::where('is_active', true)->whereNotIn('id', $earnedIds)->get();

        if ($badges->isEmpty()) {
            return [];
        }

        $values = $this->badgeValues($user, (int) $progress->current_streak, (int) $progress->level);

        $newBadges = [];
        foreach ($badges as $badge) {
            $value = $values[$badge->condition_type] ?? null;
            if ($value !== null && $value >= $badge->threshold) {
                $user->badges()->attach($badge->id, ['awarded_at' => now()]);
                $newBadges[] = ['code' => $badge->code, 'name' => $badge->name];
            }
        }

        return $newBadges;
    }
}
