<?php

namespace App\Models;

use App\Services\PetEvolutionService;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'stage'])]
class Pet extends Model
{
    /**
     * Set the correct initial stage when a pet
     * is first created for an existing student.
     */
    protected static function booted(): void
    {
        static::creating(function (
            self $pet
        ): void {
            if (!$pet->user_id) {
                return;
            }

            $user = User::find($pet->user_id);

            if (!$user) {
                return;
            }

            $totalXp = (int) (
                $user->progress?->total_xp ?? 0
            );

            $pet->stage =
                PetEvolutionService::stageForTotalXp(
                    $totalXp
                );
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
