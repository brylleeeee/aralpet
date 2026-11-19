<?php

namespace Tests\Feature;

use App\Models\Badge;
use App\Models\Setting;
use App\Models\Task;
use App\Models\User;
use Database\Seeders\BadgeSeeder;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, BadgeSeeder::class]);
        $this->travelTo(now()->setDate(2026, 11, 18)->setTime(9, 0));
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['name' => 'Administrator']);
        $admin->role = 'admin';
        $admin->is_active = true;
        $admin->save();
        Sanctum::actingAs($admin);

        return $admin;
    }

    private function student(string $name = 'Ana Cruz'): User
    {
        $user = User::factory()->create(['name' => $name, 'role' => 'student', 'is_active' => true]);
        $user->progress()->create();
        $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);

        return $user;
    }

    // ---------- Access ----------

    public function test_students_cannot_use_admin_routes(): void
    {
        Sanctum::actingAs($this->student());

        foreach (['users', 'reports', 'badges', 'settings'] as $path) {
            $this->getJson("/api/v1/admin/{$path}")->assertForbidden();
        }
    }

    public function test_admin_cannot_use_student_routes(): void
    {
        $this->admin();
        $this->getJson('/api/v1/progress')->assertForbidden();
    }

    // ---------- Users ----------

    public function test_admin_lists_and_searches_users(): void
    {
        $this->admin();
        $this->student('Ana Cruz');
        $this->student('Ben Reyes');

        $this->getJson('/api/v1/admin/users')
            ->assertOk()
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('data.0.role', 'admin')
            ->assertJsonStructure(['data' => [['id', 'name', 'email', 'is_active', 'level', 'total_xp', 'streak_days']]]);

        $this->getJson('/api/v1/admin/users?search=ben')
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.name', 'Ben Reyes');
    }

    public function test_deactivating_signs_the_student_out(): void
    {
        $student = $this->student();
        $token = $student->createToken('phone')->plainTextToken;

        $this->admin();
        $this->patchJson("/api/v1/admin/users/{$student->id}/status", ['is_active' => false])
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->assertSame(0, $student->tokens()->count());

        // The old token no longer works, and login is refused.
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
        $this->postJson('/api/v1/auth/login', ['email' => $student->email, 'password' => 'password'])
            ->assertForbidden();

        // Reactivate
        Sanctum::actingAs(User::where('role', 'admin')->first());
        $this->patchJson("/api/v1/admin/users/{$student->id}/status", ['is_active' => true])
            ->assertJsonPath('data.is_active', true);
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', ['email' => $student->email, 'password' => 'password'])
            ->assertOk();
    }

    public function test_admin_accounts_cannot_be_deactivated(): void
    {
        $admin = $this->admin();

        $this->patchJson("/api/v1/admin/users/{$admin->id}/status", ['is_active' => false])
            ->assertStatus(422);
    }

    // ---------- Badges ----------

    public function test_admin_creates_edits_and_disables_badges(): void
    {
        $this->admin();

        $id = $this->postJson('/api/v1/admin/badges', [
            'code' => 'task_legend',
            'name' => 'Task Legend',
            'description' => 'Complete 100 tasks.',
            'condition_type' => 'tasks_completed',
            'threshold' => 100,
        ])->assertCreated()->json('data.id');

        $this->postJson('/api/v1/admin/badges', [
            'code' => 'task_legend', 'name' => 'Copy', 'description' => 'x',
            'condition_type' => 'magic', 'threshold' => 0,
        ])->assertStatus(422)->assertJsonValidationErrors(['code', 'condition_type', 'threshold']);

        $this->putJson("/api/v1/admin/badges/{$id}", [
            'code' => 'task_legend',
            'name' => 'Task Legend',
            'description' => 'Complete 80 tasks.',
            'condition_type' => 'tasks_completed',
            'threshold' => 80,
            'is_active' => false,
        ])->assertOk()
            ->assertJsonPath('data.threshold', 80)
            ->assertJsonPath('data.is_active', false);

        $this->getJson('/api/v1/admin/badges')->assertJsonCount(9, 'data');
    }

    public function test_new_badge_is_awarded_to_students(): void
    {
        $this->admin();
        $this->postJson('/api/v1/admin/badges', [
            'code' => 'first_task', 'name' => 'First Task', 'description' => 'Complete a task.',
            'condition_type' => 'tasks_completed', 'threshold' => 1,
        ])->assertCreated();

        $student = $this->student();
        Sanctum::actingAs($student);
        $task = new Task(['title' => 'Read', 'priority' => 'low']);
        $task->user_id = $student->id;
        $task->status = 'pending';
        $task->save();

        $this->postJson("/api/v1/tasks/{$task->id}/complete")
            ->assertJsonPath('new_badges.0.code', 'first_task');
    }

    // ---------- Settings ----------

    public function test_admin_changes_xp_rules_and_they_apply_at_once(): void
    {
        $this->admin();

        $this->getJson('/api/v1/admin/settings')
            ->assertOk()
            ->assertJsonCount(6, 'data')
            ->assertJsonPath('data.0.key', 'daily_xp_cap')
            ->assertJsonPath('data.0.value', 300);

        $this->putJson('/api/v1/admin/settings', ['task_xp' => 25, 'daily_xp_cap' => 400])
            ->assertOk();

        $this->assertSame('25', Setting::get('task_xp'));

        $student = $this->student();
        Sanctum::actingAs($student);
        $task = new Task(['title' => 'Read', 'priority' => 'low']);
        $task->user_id = $student->id;
        $task->status = 'pending';
        $task->save();

        $this->postJson("/api/v1/tasks/{$task->id}/complete")->assertJsonPath('xp_earned', 25);
    }

    public function test_settings_are_validated(): void
    {
        $this->admin();

        $this->putJson('/api/v1/admin/settings', ['daily_xp_cap' => -5])
            ->assertStatus(422)->assertJsonValidationErrors('daily_xp_cap');

        $this->putJson('/api/v1/admin/settings', ['min_session_minutes' => 50, 'max_session_minutes' => 30])
            ->assertStatus(422)->assertJsonValidationErrors('min_session_minutes');
    }

    // ---------- Reports ----------

    public function test_reports_total_the_week(): void
    {
        $student = $this->student();
        Sanctum::actingAs($student);

        $id = $this->postJson('/api/v1/sessions', ['planned_minutes' => 25])->json('data.id');
        $this->travel(25)->minutes();
        $this->patchJson("/api/v1/sessions/{$id}/finish")->assertOk();

        $this->student('Idle Student');

        $this->admin();
        $this->getJson('/api/v1/admin/reports?period=week')
            ->assertOk()
            ->assertJsonPath('data.start_date', '2026-11-16')
            ->assertJsonPath('data.total_students', 2)
            ->assertJsonPath('data.active_students', 1)
            ->assertJsonPath('data.sessions', 1)
            ->assertJsonPath('data.total_minutes', 25)
            ->assertJsonPath('data.xp_awarded', 25)
            ->assertJsonPath('data.badges_awarded', 1)
            ->assertJsonPath('data.badges.0.name', 'First Focus');

        $this->getJson('/api/v1/admin/reports?period=month')
            ->assertJsonPath('data.start_date', '2026-11-01')
            ->assertJsonPath('data.end_date', '2026-11-30');

        $this->getJson('/api/v1/admin/reports?period=week&date=2026-11-01')
            ->assertJsonPath('data.sessions', 0);
    }
}
