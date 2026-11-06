<?php

namespace App\Models;

use App\Services\PetEvolutionService;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'total_xp',
    'level',
    'current_streak',
    'longest_streak',
    'last_active_on',
])]
class Progress extends Model
{
    protected $table = 'progress';

    protected function casts(): array
    {
        return [
            'total_xp' => 'integer',
            'level' => 'integer',
            'current_streak' => 'integer',
            'longest_streak' => 'integer',
            'last_active_on' => 'date',
        ];
    }

    /**
     * Automatically synchronize pet evolution
     * whenever progress is saved through Eloquent.
     */
    protected static function booted(): void
    {
        static::saved(function (
            self $progress
        ): void {
            PetEvolutionService::sync($progress);
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
