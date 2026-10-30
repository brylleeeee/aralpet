<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TaskResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'title'        => $this->title,
            'notes'        => $this->notes,
            'due_date'     => $this->due_date?->toDateString(),   // "2026-11-05"
            'priority'     => $this->priority,
            'status'       => $this->status,
            'completed_at' => $this->completed_at,
            'subject_id'   => $this->subject_id,
            'subject'      => new SubjectResource($this->whenLoaded('subject')),
            'created_at'   => $this->created_at,
        ];
    }
}