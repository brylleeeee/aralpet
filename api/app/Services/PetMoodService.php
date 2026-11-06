<?php

namespace App\Services;

use App\Models\Progress;
use Illuminate\Support\Carbon;

class PetMoodService
{
    /**
     * Determine mood from the last day XP was earned.
     * All dates follow the Asia/Manila timezone.
     *
     * happy - XP earned today
     * okay  - XP earned yesterday or no XP history
     * sad   - no XP earned for two or more days
     */
    public static function fromLastActiveDate(
        ?string $lastActiveDate,
        ?string $today = null
    ): string {
        $today ??= Carbon::today(
            GamificationService::TIMEZONE
        )->toDateString();

        // The student earned XP today.
        if ($lastActiveDate === $today) {
            return 'happy';
        }

        // New students start with a neutral mood.
        if (
            $lastActiveDate === null ||
            $lastActiveDate === ''
        ) {
            return 'okay';
        }

        $yesterday = Carbon::parse(
            $today,
            GamificationService::TIMEZONE
        )->subDay()->toDateString();

        // The student was last active yesterday.
        if ($lastActiveDate === $yesterday) {
            return 'okay';
        }

        // Protect against future-dated activity records.
        if ($lastActiveDate > $today) {
            return 'okay';
        }

        // No XP activity for two or more days.
        return 'sad';
    }

    /**
     * Calculate the current pet mood from
     * an existing student Progress model.
     */
    public static function forProgress(
        ?Progress $progress
    ): string {
        return self::fromLastActiveDate(
            $progress?->last_active_on?->toDateString()
        );
    }
}
