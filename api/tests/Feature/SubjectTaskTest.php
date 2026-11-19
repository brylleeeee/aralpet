<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SubjectTaskTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(SettingSeeder::class);
        $this->travelTo(now()->setDate(2026, 11, 18)->setTime(9, 0)); // Wednesday
    }

    private function student(): User
    {
        $user = User::factory()->create(['role' => 'student', 'is_active' => true]);
        $user->progress()->create();
        $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);
        Sanctum::actingAs($user);

        return $user;
    }

    private function subject(string $name = 'Math', string $color = '#38BDF8'): int
    {
        return $this->postJson('/api/v1/subjects', ['name' => $name, 'color' => $color])
            ->assertCreated()
            ->json('data.id');
    }

    public function test_subject_crud(): void
    {
        $this->student();
        $id = $this->subject();

        $this->getJson('/api/v1/subjects')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Math')
            ->assertJsonPath('data.0.tasks_count', 0);

        $this->putJson("/api/v1/subjects/{$id}", ['name' => 'Calculus', 'color' => '#34D399'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Calculus');

        $this->deleteJson("/api/v1/subjects/{$id}")->assertNoContent();
        $this->getJson('/api/v1/subjects')->assertJsonCount(0, 'data');
    }

    public function test_subject_is_validated(): void
    {
        $this->student();
        $this->subject('Math');

        $this->postJson('/api/v1/subjects', ['name' => 'Math', 'color' => '#38BDF8'])
            ->assertStatus(422)->assertJsonValidationErrors('name');
        $this->postJson('/api/v1/subjects', ['name' => 'Science', 'color' => 'blue'])
            ->assertStatus(422)->assertJsonValidationErrors('color');
    }

    public function test_students_only_see_their_own_subjects(): void
    {
        $this->student();
        $id = $this->subject('Math');

        $this->student();
        $this->subject('Math'); // the same name is fine for another student
        $this->getJson('/api/v1/subjects')->assertJsonCount(1, 'data');
        $this->putJson("/api/v1/subjects/{$id}", ['name' => 'Mine', 'color' => '#38BDF8'])->assertForbidden();
        $this->deleteJson("/api/v1/subjects/{$id}")->assertForbidden();
    }

    public function test_task_with_subject_and_deleting_the_subject_keeps_the_task(): void
    {
        $this->student();
        $subjectId = $this->subject('Math', '#F472B6');

        $taskId = $this->postJson('/api/v1/tasks', ['title' => 'Problem set', 'subject_id' => $subjectId])
            ->assertCreated()
            ->assertJsonPath('data.subject.name', 'Math')
            ->assertJsonPath('data.subject.color', '#F472B6')
            ->json('data.id');

        $this->getJson('/api/v1/subjects')->assertJsonPath('data.0.tasks_count', 1);

        $this->deleteJson("/api/v1/subjects/{$subjectId}")->assertNoContent();

        $this->getJson('/api/v1/tasks')
            ->assertJsonPath('data.0.id', $taskId)
            ->assertJsonPath('data.0.subject_id', null);
    }

    public function test_task_cannot_use_another_students_subject(): void
    {
        $this->student();
        $subjectId = $this->subject();

        $this->student();
        $this->postJson('/api/v1/tasks', ['title' => 'Sneaky', 'subject_id' => $subjectId])
            ->assertStatus(422)->assertJsonValidationErrors('subject_id');
    }

    public function test_task_due_filters(): void
    {
        $this->student();
        $this->postJson('/api/v1/tasks', ['title' => 'Today', 'due_date' => '2026-11-18']);
        $this->postJson('/api/v1/tasks', ['title' => 'Friday', 'due_date' => '2026-11-20']);
        $this->postJson('/api/v1/tasks', ['title' => 'Next week', 'due_date' => '2026-11-25']);
        $this->postJson('/api/v1/tasks', ['title' => 'Late', 'due_date' => '2026-11-10']);

        $titles = fn (string $due) => collect($this->getJson("/api/v1/tasks?due={$due}")->json('data'))
            ->pluck('title')->sort()->values()->all();

        $this->assertSame(['Today'], $titles('today'));
        $this->assertSame(['Friday', 'Today'], $titles('week'));
        $this->assertSame(['Late'], $titles('overdue'));
    }

    public function test_task_list_is_paginated(): void
    {
        $this->student();
        for ($i = 1; $i <= 17; $i++) {
            $this->postJson('/api/v1/tasks', ['title' => "Task {$i}"])->assertCreated();
        }

        $this->getJson('/api/v1/tasks')
            ->assertJsonCount(15, 'data')
            ->assertJsonPath('meta.last_page', 2);
        $this->getJson('/api/v1/tasks?page=2')->assertJsonCount(2, 'data');
    }
}
