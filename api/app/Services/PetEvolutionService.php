<?php

namespace App\Services;

use App\Models\Progress;

class PetEvolutionService
{
    /**
     * Determine the pet stage from a student level.
     */
    public static function stageForLevel(int $level): string
    {
        if ($level >= 20) {
            return 'elder';
        }

        if ($level >= 10) {
            return 'adult';
        }

        if ($level >= 5) {
            return 'junior';
        }

        if ($level >= 2) {
            return 'hatchling';
        }

        return 'egg';
    }

    /**
     * Determine pet stage directly from total XP.
     */
    public static function stageForTotalXp(
        int $totalXp
    ): string {
        $level = GamificationService::levelForTotalXp(
            $totalXp
        );

        return self::stageForLevel($level);
    }

    /**
     * Synchronize an existing student's pet
     * with the student's current total XP.
     *
     * This does not create a pet automatically,
     * preserving the existing pet-creation flow.
     */
    public static function sync(
        Progress $progress
    ): void {
        $user = $progress->user;

        if (!$user) {
            return;
        }

        $pet = $user->pet()->first();

        if (!$pet) {
            return;
        }

        $newStage = self::stageForTotalXp(
            (int) $progress->total_xp
        );

        if ($pet->stage === $newStage) {
            return;
        }

        // Update only the stage.
        // The pet's chosen name stays unchanged.
        $pet->stage = $newStage;
        $pet->save();
    }
}
