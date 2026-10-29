<?php

namespace App\Policies;

use App\Models\Subject;
use App\Models\User;

class SubjectPolicy
{
    public function update(User $user, Subject $subject): bool
    {
        return $user->id === $subject->user_id;
    }

    public function delete(User $user, Subject $subject): bool
    {
        return $user->id === $subject->user_id;
    }
}