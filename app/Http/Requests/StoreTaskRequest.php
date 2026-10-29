<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;   // ownership is checked by TaskPolicy
    }

    public function rules(): array
    {
        return [
            'title'      => ['required', 'string', 'max:255'],
            'subject_id' => [
                'nullable', 'integer',
                // the subject must exist AND belong to this student
                Rule::exists('subjects', 'id')->where('user_id', $this->user()->id),
            ],
            'notes'      => ['nullable', 'string', 'max:2000'],
            'due_date'   => ['nullable', 'date'],
            'priority'   => ['sometimes', 'in:low,medium,high'],
        ];
    }
}