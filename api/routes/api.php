
<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ProgressController;
use App\Http\Controllers\Api\V1\SubjectController;
use App\Http\Controllers\Api\V1\TaskController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // Authentication routes
    Route::post('auth/register', [AuthController::class, 'register']);

    Route::post('auth/login', [AuthController::class, 'login'])
        ->middleware('throttle:login');

    // Protected routes
    Route::middleware(['auth:sanctum', 'active'])->group(function () {

        // User account routes
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        Route::put('me', [AuthController::class, 'update']);

        // Student routes
        Route::middleware('role:student')->group(function () {

            // Dashboard progress
            Route::get('progress', [ProgressController::class, 'show']);

            // Subject management
            Route::apiResource('subjects', SubjectController::class)
                ->except('show');

            // Task management
            Route::apiResource('tasks', TaskController::class)
                ->except('show');

            // Complete a task and earn XP
            Route::post('tasks/{task}/complete', [
                TaskController::class,
                'complete',
            ])->name('tasks.complete');

        });

        // Admin routes (role:admin) will be added later.
    });
});
