<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BadgeController;
use App\Http\Controllers\Api\V1\FocusSessionController;
use App\Http\Controllers\Api\V1\PetController;
use App\Http\Controllers\Api\V1\ProgressController;
use App\Http\Controllers\Api\V1\SubjectController;
use App\Http\Controllers\Api\V1\SummaryController;
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

            // Focus sessions (timed by the server)
            Route::get('sessions', [FocusSessionController::class, 'index']);
            Route::post('sessions', [FocusSessionController::class, 'store']);
            Route::patch('sessions/{session}/finish', [FocusSessionController::class, 'finish'])
                ->whereNumber('session');
            Route::patch('sessions/{session}/cancel', [FocusSessionController::class, 'cancel'])
                ->whereNumber('session');

            // Pet, badges and weekly summary
            Route::get('pet', [PetController::class, 'show']);
            Route::put('pet', [PetController::class, 'update']);
            Route::get('badges', [BadgeController::class, 'index']);
            Route::get('summary/weekly', [SummaryController::class, 'weekly']);

        });

        // Administrator routes
        Route::middleware('role:admin')->prefix('admin')->group(function () {
            Route::get('users', [Admin\UserController::class, 'index']);
            Route::patch('users/{user}/status', [Admin\UserController::class, 'updateStatus']);
            Route::get('reports', [Admin\ReportController::class, 'index']);
            Route::get('badges', [Admin\BadgeController::class, 'index']);
            Route::post('badges', [Admin\BadgeController::class, 'store']);
            Route::put('badges/{badge}', [Admin\BadgeController::class, 'update']);
            Route::get('settings', [Admin\SettingController::class, 'index']);
            Route::put('settings', [Admin\SettingController::class, 'update']);
        });
    });
});
