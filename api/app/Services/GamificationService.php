<?php

namespace App\Services;

use App\Models\Progress;
use App\Models\Setting;
use App\Models\User;
use App\Models\XpLedger;
use Illuminate\Support\Carbon;

class GamificationService
{
    public const TASK_XP = 10;
    public const ON_TIME_BONUS_XP = 5;
    public const DAILY_XP_CAP = 300;
    public const TIMEZONE = 'Asia/Manila';

    /**
     * 10 XP for a completed task.
     * Additional 5 XP if completed on time.
     */
    public static function taskCompletionXp(
        ?string $dueDate,
        string $completedOn
    ): int {
        $xp = self::TASK_XP;

        if ($dueDate !== null && $completedOn <= $dueDate) {
            $xp += self::ON_TIME_BONUS_XP;
        }

        return $xp;
    }

    /**
     * XP threshold: 50 * L * (L - 1).
     */
    public static function xpThresholdForLevel(int $level): int
    {
        return $level <= 1
            ? 0
            : 50 * $level * ($level - 1);
    }

    public static function levelForTotalXp(int $totalXp): int
    {
        $level = 1;
        $totalXp = max(0, $totalXp);

        while (
            $totalXp >=
            self::xpThresholdForLevel($level + 1)
        ) {
            $level++;
        }

        return $level;
    }

    public static function xpIntoLevel(int $totalXp): int
    {
        $totalXp = max(0, $totalXp);

        $level = self::levelForTotalXp($totalXp);

        return $totalXp -
            self::xpThresholdForLevel($level);
    }

    public static function xpForNextLevel(int $totalXp): int
    {
        $level = self::levelForTotalXp($totalXp);

        return self::xpThresholdForLevel($level + 1)
            - self::xpThresholdForLevel($level);
    }

    /**
     * Read the administrator-configurable daily cap.
     * Default: 300 XP.
     */
    public static function dailyXpCap(): int
    {
        $value = Setting::query()
            ->where('key', 'daily_xp_cap')
            ->value('value');

        if (
            $value === null ||
            !ctype_digit(trim((string) $value))
        ) {
            return self::DAILY_XP_CAP;
        }

        return (int) $value;
    }

    /**
     * Sum XP awarded on a specific Manila date.
     */
    public static function xpEarnedToday(
        int $userId,
        string $manilaDate
    ): int {
        return (int) XpLedger::query()
            ->where('user_id', $userId)
            ->where('earned_on', $manilaDate)
            ->sum('amount');
    }

    /**
     * Record one XP award.
     *
     * IMPORTANT:
     * Call inside a DB transaction AFTER locking
     * the user's row using lockForUpdate().
     *
     * A ledger record is saved even when the
     * daily limit reduces the award to zero.
     */
    public static function awardXp(
        User $user,
        Progress $progress,
        string $sourceType,
        int $sourceId,
        int $requestedXp,
        Carbon $earnedAt
    ): array {
        // Prevent claiming an existing reward.
        $alreadyRecorded = XpLedger::query()
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->exists();

        if ($alreadyRecorded) {
            abort(
                409,
                'This reward has already been recorded.'
            );
        }

        // Convert the reward date to Manila time.
        $manilaDate = $earnedAt
            ->copy()
            ->setTimezone(self::TIMEZONE)
            ->toDateString();

        // Read daily XP settings.
        $cap = self::dailyXpCap();

        // Calculate how much XP was earned today.
        $alreadyEarned = self::xpEarnedToday(
            (int) $user->getKey(),
            $manilaDate
        );

        // Only award the remaining daily XP.
        $availableXp = max(
            0,
            $cap - $alreadyEarned
        );

        $awardedXp = min(
            max(0, $requestedXp),
            $availableXp
        );

        // Save the reward in the XP ledger.
        $entry = new XpLedger([
            'source_type' => $sourceType,
            'source_id' => $sourceId,
            'amount' => $awardedXp,
            'earned_on' => $manilaDate,
        ]);

        // Set the user_id through the relationship.
        $entry->user()->associate($user);
        $entry->save();

        // Only positive XP counts toward streaks.
        if ($awardedXp > 0) {
            self::applyXpToProgress(
                $progress,
                $awardedXp,
                $manilaDate
            );
        } else {
            // Keep the stored level consistent.
            $progress->level =
                self::levelForTotalXp(
                    (int) $progress->total_xp
                );

            $progress->save();
        }

        return [
            'xp_earned' => $awardedXp,
            'xp_today' =>
                $alreadyEarned + $awardedXp,
            'daily_xp_cap' => $cap,
        ];
    }

    /**
     * Update total XP, level, and streak.
     */
    private static function applyXpToProgress(
        Progress $progress,
        int $earnedXp,
        string $manilaDate
    ): void {
        $yesterday = Carbon::parse(
            $manilaDate,
            self::TIMEZONE
        )->subDay()->toDateString();

        $lastActiveDate = $progress->last_active_on
            ? Carbon::parse(
                $progress->last_active_on,
                self::TIMEZONE
            )->toDateString()
            : null;

        $currentStreak = (int) (
            $progress->current_streak ?? 0
        );

        if ($lastActiveDate === $manilaDate) {
            // Already studied today.
            $currentStreak = max(
                1,
                $currentStreak
            );
        } elseif ($lastActiveDate === $yesterday) {
            // Consecutive study day.
            $currentStreak++;
        } else {
            // New or restarted streak.
            $currentStreak = 1;
        }

        $totalXp =
            (int) ($progress->total_xp ?? 0)
            + $earnedXp;

        $progress->total_xp = $totalXp;

        $progress->level =
            self::levelForTotalXp($totalXp);

        $progress->current_streak =
            $currentStreak;

        $progress->longest_streak = max(
            (int) ($progress->longest_streak ?? 0),
            $currentStreak
        );

        $progress->last_active_on =
            $manilaDate;

        $progress->save();
    }
}
