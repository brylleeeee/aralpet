<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSubjectRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;   // ownership is checked by SubjectPolicy
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required', 'string', 'max:100',
                // no two subjects with the same name for one student
                Rule::unique('subjects')
                    ->where('user_id', $this->user()->id)
                    ->ignore($this->route('subject')),
            ],
            'color' => ['required', 'string', 'regex:/^#[0-9A-Fa-f]{6}$/'],
        ];
    }

    public function messages(): array
    {
        return [
            'color.regex' => 'The color must be a hex code like #4F46E5.',
        ];
    }
}