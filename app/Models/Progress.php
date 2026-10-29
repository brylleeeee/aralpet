<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['total_xp', 'level', 'current_streak', 'longest_streak', 'last_active_on'])]
class Progress extends Model
{
    protected $table = 'progress';

    protected function casts(): array
    {
        return [
            'last_active_on' => 'date',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}