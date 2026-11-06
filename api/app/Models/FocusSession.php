<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'task_id',
    'started_at',
    'ended_at',
    'planned_minutes',
    'duration_minutes',
    'status',
    'segment_started_at',
    'accumulated_seconds',
    'paused_at',
])]
class FocusSession extends Model
{
    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'segment_started_at' => 'datetime',
            'paused_at' => 'datetime',
            'accumulated_seconds' => 'integer',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function task()
    {
        return $this->belongsTo(Task::class);
    }
}
