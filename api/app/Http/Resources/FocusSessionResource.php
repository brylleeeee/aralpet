<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FocusSessionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'               => $this->id,
            'task_id'          => $this->task_id,
            'task_title'       => $this->whenLoaded('task', fn () => $this->task?->title),
            'status'           => $this->status,            // active, finished, cancelled
            'planned_minutes'  => $this->planned_minutes,
            'duration_minutes' => $this->duration_minutes,  // computed by the server
            'started_at'       => $this->started_at,
            'ended_at'         => $this->ended_at,
        ];
    }
}
