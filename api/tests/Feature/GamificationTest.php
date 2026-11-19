<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\Task;
use App\Models\User;
use Database\Seeders\BadgeSeeder;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GamificationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, BadgeSeeder::class]);
        $this->travelTo(now()->setTime(9, 0));
    }

    private function student(): User
    {
        $user = User::factory()->create(['role' => 'student', 'is_active' => true]);
        $user->progress()->create();
        $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);
        Sanctum::actingAs($user);

        return $user;
    }

    private function task(User $user, array $attrs = []): Task
    {
        $task = new Task(array_merge(['title' => 'Read chapter 1', 'priority' => 'medium'], $attrs));
        $task->user_id = $user->id;
        $task->status = 'pending';
        $task->save();

        return $task;
    }

    // Starts a session and moves the clock forward by $minutes.
    private function runSession(int $planned, int $minutes, ?int $taskId = null): int
    {
        $id = $this->postJson('/api/v1/sessions', ['planned_minutes' => $planned, 'task_id' => $taskId])
            ->assertCreated()
            ->json('data.id');
        $this->travel($minutes)->minutes();

        return $id;
    }

    // ---------- Sessions ----------

    public function test_finished_session_earns_one_xp_per_minute(): void
    {
        $this->student();
        $id = $this->runSession(25, 25);

        $this->patchJson("/api/v1/sessions/{$id}/finish")
            ->assertOk()
            ->assertJsonPath('data.xp_awarded', 25)
            ->assertJsonPath('data.session.duration_minutes', 25)
            ->assertJsonPath('data.progress.total_xp', 25);
    }

    public function test_duration_comes_from_the_server_not_the_client(): void
    {
        $this->student();
        $id = $this->runSession(30, 12);

        $this->patchJson("/api/v1/sessions/{$id}/finish", ['duration_minutes' => 30])
            ->assertOk()
            ->assertJsonPath('data.session.duration_minutes', 12)
            ->assertJsonPath('data.xp_awarded', 12);
    }

    public function test_session_shorter_than_minimum_earns_nothing_and_no_streak(): void
    {
        $user = $this->student();
        $id = $this->runSession(25, 5);

        $this->patchJson("/api/v1/sessions/{$id}/finish")
            ->assertOk()
            ->assertJsonPath('data.qualifies', false)
            ->assertJsonPath('data.xp_awarded', 0);

        $this->assertSame(0, (int) $user->progress->fresh()->current_streak);
    }

    public function test_session_xp_is_limited_to_planned_and_max_minutes(): void
    {
        $this->student();
        $id = $this->runSession(25, 90); // left running long after the timer

        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertJsonPath('data.xp_awarded', 25);

        $id = $this->runSession(120, 120);
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertJsonPath('data.xp_awarded', 60);
    }

    public function test_planned_minutes_below_minimum_is_rejected(): void
    {
        $this->student();

        $this->postJson('/api/v1/sessions', ['planned_minutes' => 3])
            ->assertStatus(422)
            ->assertJsonValidationErrors('planned_minutes');
    }

    public function test_only_one_active_session_at_a_time(): void
    {
        $this->student();
        $this->postJson('/api/v1/sessions', ['planned_minutes' => 25])->assertCreated();

        $this->postJson('/api/v1/sessions', ['planned_minutes' => 25])
            ->assertStatus(409)
            ->assertJsonPath('active_session.status', 'active');
    }

    public function test_finishing_twice_returns_409_and_no_double_xp(): void
    {
        $user = $this->student();
        $id = $this->runSession(25, 25);

        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertOk();
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertStatus(409);

        $this->assertSame(25, (int) $user->progress->fresh()->total_xp);
    }

    public function test_cancel_gives_no_xp(): void
    {
        $user = $this->student();
        $id = $this->runSession(25, 15);

        $this->patchJson("/api/v1/sessions/{$id}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertStatus(409);

        $this->assertSame(0, (int) $user->progress->fresh()->total_xp);
    }

    public function test_student_cannot_touch_another_students_session(): void
    {
        $this->student();
        $id = $this->runSession(25, 25);

        $this->student(); // log in as someone else
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertNotFound();
    }

    public function test_session_task_must_belong_to_the_student(): void
    {
        $owner = $this->student();
        $task = $this->task($owner);

        $this->student();
        $this->postJson('/api/v1/sessions', ['planned_minutes' => 25, 'task_id' => $task->id])
            ->assertStatus(422)
            ->assertJsonValidationErrors('task_id');
    }

    // ---------- Tasks ----------

    public function test_task_xp_with_on_time_bonus(): void
    {
        $user = $this->student();
        $onTime = $this->task($user, ['due_date' => today()->addDay()->toDateString()]);
        $late = $this->task($user, ['due_date' => today()->subDay()->toDateString()]);
        $noDue = $this->task($user);

        $this->postJson("/api/v1/tasks/{$onTime->id}/complete")->assertJsonPath('xp_earned', 15);
        $this->postJson("/api/v1/tasks/{$late->id}/complete")->assertJsonPath('xp_earned', 10);
        $this->postJson("/api/v1/tasks/{$noDue->id}/complete")->assertJsonPath('xp_earned', 10);
    }

    public function test_task_completed_twice_gives_xp_once(): void
    {
        $user = $this->student();
        $task = $this->task($user);

        $this->postJson("/api/v1/tasks/{$task->id}/complete")->assertJsonPath('xp_earned', 10);
        $this->postJson("/api/v1/tasks/{$task->id}/complete")
            ->assertJsonPath('already_completed', true)
            ->assertJsonPath('xp_earned', 0);

        $this->assertSame(10, (int) $user->progress->fresh()->total_xp);
    }

    public function test_task_xp_follows_admin_settings(): void
    {
        Setting::where('key', 'task_xp')->update(['value' => '50']);
        $user = $this->student();
        $task = $this->task($user);

        $this->postJson("/api/v1/tasks/{$task->id}/complete")->assertJsonPath('xp_earned', 50);
    }

    // ---------- Shared rules ----------

    public function test_daily_cap_stops_xp_after_300(): void
    {
        $user = $this->student();

        for ($i = 0; $i < 5; $i++) {
            $id = $this->runSession(60, 60);
            $this->patchJson("/api/v1/sessions/{$id}/finish")->assertOk();
        }
        $this->assertSame(300, (int) $user->progress->fresh()->total_xp);

        $id = $this->runSession(60, 60);
        $this->patchJson("/api/v1/sessions/{$id}/finish")
            ->assertJsonPath('data.xp_awarded', 0)
            ->assertJsonPath('data.capped', true);
    }

    public function test_level_follows_xp(): void
    {
        $user = $this->student();
        $user->progress->update(['total_xp' => 90]);
        $id = $this->runSession(25, 25);

        $this->patchJson("/api/v1/sessions/{$id}/finish")
            ->assertJsonPath('data.leveled_up', true)
            ->assertJsonPath('data.progress.level', 2)
            ->assertJsonPath('data.progress.xp_into_level', 15)
            ->assertJsonPath('data.progress.xp_for_next_level', 150);
    }

    public function test_streak_grows_on_consecutive_days_and_resets_after_a_gap(): void
    {
        $user = $this->student();

        foreach ([0, 1, 1] as $days) {
            $this->travel($days)->days();
            $task = $this->task($user);
            $this->postJson("/api/v1/tasks/{$task->id}/complete")->assertOk();
        }
        $this->assertSame(3, (int) $user->progress->fresh()->current_streak);

        $this->travel(2)->days(); // missed a day
        $this->getJson('/api/v1/progress')->assertJsonPath('streak_days', 0);

        $task = $this->task($user);
        $this->postJson("/api/v1/tasks/{$task->id}/complete");
        $progress = $user->progress->fresh();
        $this->assertSame(1, (int) $progress->current_streak);
        $this->assertSame(3, (int) $progress->longest_streak);
    }

    public function test_pet_evolves_with_level_and_mood_follows_activity(): void
    {
        $user = $this->student();
        $this->getJson('/api/v1/progress')->assertJsonPath('pet_stage', 'egg');

        $task = $this->task($user);
        $this->postJson("/api/v1/tasks/{$task->id}/complete");
        $user->progress->update(['total_xp' => 95]);
        $task = $this->task($user);

        $this->postJson("/api/v1/tasks/{$task->id}/complete")
            ->assertJsonPath('pet_evolved', true)
            ->assertJsonPath('progress.pet_stage', 'hatchling')
            ->assertJsonPath('progress.pet_mood', 'happy');

        $this->travel(1)->days();
        $this->getJson('/api/v1/progress')->assertJsonPath('pet_mood', 'okay');
        $this->travel(2)->days();
        $this->getJson('/api/v1/progress')
            ->assertJsonPath('pet_mood', 'sleepy')
            ->assertJsonPath('pet_stage', 'hatchling'); // mood never lowers the stage
    }

    public function test_badges_are_awarded_once(): void
    {
        $user = $this->student();
        $id = $this->runSession(25, 25);

        $this->patchJson("/api/v1/sessions/{$id}/finish")
            ->assertJsonPath('data.new_badges.0.code', 'first_focus');

        $id = $this->runSession(25, 25);
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertJsonCount(0, 'data.new_badges');

        $this->assertSame(1, $user->badges()->count());
    }

    public function test_progress_endpoint_shape(): void
    {
        $this->student();

        $this->getJson('/api/v1/progress')
            ->assertOk()
            ->assertJsonStructure([
                'user_name', 'level', 'total_xp', 'xp_into_level', 'xp_for_next_level',
                'xp_today', 'daily_cap', 'streak_days', 'longest_streak', 'minutes_today',
                'tasks_due_today', 'pet_name', 'pet_stage', 'pet_mood', 'next_stage_level',
            ]);
    }
}
