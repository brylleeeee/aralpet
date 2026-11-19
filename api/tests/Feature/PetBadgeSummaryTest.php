<?php

namespace Tests\Feature;

use App\Models\Badge;
use App\Models\Task;
use App\Models\User;
use Database\Seeders\BadgeSeeder;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PetBadgeSummaryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, BadgeSeeder::class]);
        // A Wednesday morning in Manila time
        $this->travelTo(now()->setDate(2026, 11, 18)->setTime(9, 0));
    }

    private function student(): User
    {
        $user = User::factory()->create(['role' => 'student', 'is_active' => true]);
        $user->progress()->create();
        $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);
        Sanctum::actingAs($user);

        return $user;
    }

    private function completeTask(User $user, string $title = 'Read'): void
    {
        $task = new Task(['title' => $title, 'priority' => 'medium']);
        $task->user_id = $user->id;
        $task->status = 'pending';
        $task->save();

        $this->postJson("/api/v1/tasks/{$task->id}/complete")->assertOk();
    }

    private function focus(int $minutes): void
    {
        $id = $this->postJson('/api/v1/sessions', ['planned_minutes' => max(10, $minutes)])->json('data.id');
        $this->travel($minutes)->minutes();
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertOk();
    }

    // ---------- Pet ----------

    public function test_pet_shows_stage_and_next_evolution(): void
    {
        $this->student();

        $this->getJson('/api/v1/pet')
            ->assertOk()
            ->assertJsonPath('data.name', 'Aral')
            ->assertJsonPath('data.stage', 'egg')
            ->assertJsonPath('data.next_stage', 'hatchling')
            ->assertJsonPath('data.next_stage_level', 2)
            ->assertJsonCount(5, 'data.stages')
            ->assertJsonPath('data.stages.0.reached', true)
            ->assertJsonPath('data.stages.1.reached', false);
    }

    public function test_pet_can_be_renamed(): void
    {
        $this->student();

        $this->putJson('/api/v1/pet', ['name' => '  Mochi '])
            ->assertOk()
            ->assertJsonPath('data.name', 'Mochi');

        $this->getJson('/api/v1/progress')->assertJsonPath('pet_name', 'Mochi');
    }

    public function test_pet_name_is_validated(): void
    {
        $this->student();

        $this->putJson('/api/v1/pet', ['name' => ''])->assertStatus(422)->assertJsonValidationErrors('name');
        $this->putJson('/api/v1/pet', ['name' => str_repeat('a', 51)])->assertStatus(422);
    }

    public function test_pet_requires_login(): void
    {
        $this->getJson('/api/v1/pet')->assertUnauthorized();
    }

    // ---------- Badges ----------

    public function test_badges_list_shows_earned_and_locked_with_progress(): void
    {
        $user = $this->student();
        $this->focus(25);           // earns First Focus
        $this->completeTask($user); // 1 of 10 for Task Starter

        $response = $this->getJson('/api/v1/badges')
            ->assertOk()
            ->assertJsonPath('meta.earned', 1)
            ->assertJsonPath('meta.total', 8)
            ->assertJsonPath('data.0.code', 'first_focus')
            ->assertJsonPath('data.0.earned', true);

        $this->assertNotNull($response->json('data.0.awarded_at'));

        $starter = collect($response->json('data'))->firstWhere('code', 'task_starter');
        $this->assertFalse($starter['earned']);
        $this->assertSame(1, $starter['current']);
        $this->assertSame(10, $starter['threshold']);
    }

    public function test_disabled_badges_are_hidden_unless_earned(): void
    {
        $this->student();
        $this->focus(25);
        Badge::whereIn('code', ['first_focus', 'streak_30'])->update(['is_active' => false]);

        $codes = collect($this->getJson('/api/v1/badges')->json('data'))->pluck('code');

        $this->assertContains('first_focus', $codes);   // earned, so still shown
        $this->assertNotContains('streak_30', $codes);  // disabled and not earned
    }

    // ---------- Weekly summary ----------

    public function test_weekly_summary_counts_this_week(): void
    {
        $user = $this->student();

        $this->focus(25);       // Wednesday
        $this->focus(5);        // too short: not counted as study time
        $this->completeTask($user);

        $this->travel(1)->days(); // Thursday
        $this->focus(30);

        $response = $this->getJson('/api/v1/summary/weekly')
            ->assertOk()
            ->assertJsonPath('data.start_date', '2026-11-16')
            ->assertJsonPath('data.end_date', '2026-11-22')
            ->assertJsonCount(7, 'data.days')
            ->assertJsonPath('data.days.2.day', 'Wed')
            ->assertJsonPath('data.days.2.minutes', 25)
            ->assertJsonPath('data.days.2.sessions', 1)
            ->assertJsonPath('data.days.2.tasks_completed', 1)
            ->assertJsonPath('data.days.2.xp', 35)
            ->assertJsonPath('data.days.3.minutes', 30)
            ->assertJsonPath('data.totals.minutes', 55)
            ->assertJsonPath('data.totals.sessions', 2)
            ->assertJsonPath('data.totals.tasks_completed', 1)
            ->assertJsonPath('data.totals.xp', 65)
            ->assertJsonCount(2, 'data.sessions');

        $this->assertSame('Read', $response->json('data.tasks.0.title'));
    }

    public function test_weekly_summary_for_another_week_and_other_students(): void
    {
        $this->student();
        $this->focus(25);

        $this->getJson('/api/v1/summary/weekly?week_of=2026-11-09')
            ->assertJsonPath('data.start_date', '2026-11-09')
            ->assertJsonPath('data.totals.minutes', 0);

        $this->student(); // someone else sees only their own data
        $this->getJson('/api/v1/summary/weekly')->assertJsonPath('data.totals.minutes', 0);

        $this->getJson('/api/v1/summary/weekly?week_of=yesterday')->assertStatus(422);
    }

    // ---------- Profile (existing PUT /me) ----------

    public function test_profile_can_be_updated(): void
    {
        $this->student();

        $this->putJson('/api/v1/me', ['name' => 'Shekinah', 'course' => 'BSIT', 'year_level' => 4])
            ->assertOk()
            ->assertJsonPath('data.name', 'Shekinah')
            ->assertJsonPath('data.year_level', 4);
    }

    public function test_password_change_needs_current_password(): void
    {
        $this->student();

        $this->putJson('/api/v1/me', [
            'password' => 'newpassword1',
            'password_confirmation' => 'newpassword1',
            'current_password' => 'wrong-password',
        ])->assertStatus(422)->assertJsonValidationErrors('current_password');
    }

    public function test_password_change_signs_out_other_devices(): void
    {
        $user = User::factory()->create(['role' => 'student', 'is_active' => true]);
        $phone = $user->createToken('phone')->plainTextToken;
        $user->createToken('laptop');

        $this->withToken($phone)->putJson('/api/v1/me', [
            'password' => 'newpassword1',
            'password_confirmation' => 'newpassword1',
            'current_password' => 'password',
        ])->assertOk();

        $this->assertSame(1, $user->tokens()->count());
    }
}
