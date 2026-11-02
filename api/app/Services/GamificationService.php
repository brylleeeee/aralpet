<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class GamificationService
{
    // Value of a row in the settings table, with a default if it is missing.
    private function setting(string $key, int $default): int
    {
        $value = DB::table('settings')->where('key', $key)->value('value');
        return $value === null ? $default : (int) $value;
    }

    // XP needed to reach level L is 50 x L x (L - 1).
    public static function xpForLevel(int $level): int
    {
        return 50 * $level * ($level - 1);
    }

    public static function levelForXp(int $xp): int
    {
        $level = 1;
        while ($xp >= self::xpForLevel($level + 1)) {
            $level++;
        }
        return $level;
    }

    public static function stageForLevel(int $level): string
    {
        return match (true) {
            $level >= 20 => 'elder',
            $level >= 10 => 'adult',
            $level >= 5 => 'junior',
            $level >= 2 => 'hatchling',
            default => 'egg',
        };
    }

    // 10 XP, plus 5 if completed on or before the due date.
    public function awardForTask(object $task): array
    {
        $today = Carbon::now('Asia/Manila')->toDateString();
        $due = $task->due_date ? substr((string) $task->due_date, 0, 10) : null;
        $amount = 10 + (($due !== null && $today <= $due) ? 5 : 0);

        return $this->award((int) $task->user_id, 'task', (int) $task->id, $amount);
    }

    // 1 XP per full minute, at most 60 per session, and nothing under the minimum.
    public function awardForSession(object $session): array
    {
        $minutes = (int) $session->duration_minutes;
        $min = $this->setting('min_session_minutes', 10);
        $max = $this->setting('max_session_minutes', 60);

        if ($minutes < $min) {
            return $this->award((int) $session->user_id, 'session', (int) $session->id, 0);
        }
        return $this->award((int) $session->user_id, 'session', (int) $session->id, min($minutes, $max));
    }

    // Call this inside a DB transaction.
    public function award(int $userId, string $type, int $sourceId, int $amount): array
    {
        $now = Carbon::now('Asia/Manila');
        $today = $now->toDateString();
        $yesterday = $now->copy()->subDay()->toDateString();
        $cap = $this->setting('daily_xp_cap', 300);

        DB::table('progress')->insertOrIgnore([
            'user_id' => $userId, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $progress = DB::table('progress')->where('user_id', $userId)->lockForUpdate()->first();

        $earnedToday = (int) DB::table('xp_ledger')
            ->where('user_id', $userId)->where('earned_on', $today)->sum('amount');

        $granted = max(0, min($amount, $cap - $earnedToday));
        $capped = $granted < $amount;

        $totalXp = (int) $progress->total_xp;
        $level = (int) $progress->level;
        $streak = (int) $progress->current_streak;
        $longest = (int) $progress->longest_streak;
        $petBefore = DB::table('pets')->where('user_id', $userId)->value('stage');
        $petStage = $petBefore;

        if ($granted > 0) {
            DB::table('xp_ledger')->insert([
                'user_id' => $userId, 'source_type' => $type, 'source_id' => $sourceId,
                'amount' => $granted, 'earned_on' => $today,
                'created_at' => now(), 'updated_at' => now(),
            ]);

            $totalXp += $granted;
            $level = self::levelForXp($totalXp);

            $last = $progress->last_active_on ? substr((string) $progress->last_active_on, 0, 10) : null;
            if ($last !== $today) {
                $streak = ($last === $yesterday) ? $streak + 1 : 1;
            }
            $longest = max($longest, $streak);

            DB::table('progress')->where('user_id', $userId)->update([
                'total_xp' => $totalXp, 'level' => $level,
                'current_streak' => $streak, 'longest_streak' => $longest,
                'last_active_on' => $today, 'updated_at' => now(),
            ]);

            $petStage = self::stageForLevel($level);
            if ($petStage !== $petBefore) {
                DB::table('pets')->where('user_id', $userId)
                    ->update(['stage' => $petStage, 'updated_at' => now()]);
            }
        }

        return [
            'xp_awarded' => $granted,
            'capped' => $capped,
            'progress' => [
                'total_xp' => $totalXp,
                'level' => $level,
                'xp_to_next_level' => self::xpForLevel($level + 1) - $totalXp,
                'xp_today' => $earnedToday + $granted,
                'daily_cap' => $cap,
                'current_streak' => $streak,
                'longest_streak' => $longest,
            ],
            'pet' => [
                'name' => DB::table('pets')->where('user_id', $userId)->value('name'),
                'stage' => $petStage,
                'evolved' => $petStage !== $petBefore,
            ],
            'new_badges' => $this->awardBadges($userId),
        ];
    }

    // Badge awarding comes next, once I have seen the BadgeSeeder.
    private function awardBadges(int $userId): array
    {
        return [];
    }
}