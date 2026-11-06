<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\FocusSessionController;
use App\Http\Controllers\Api\V1\ProgressController;
use App\Http\Controllers\Api\V1\SubjectController;
use App\Http\Controllers\Api\V1\TaskController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // ==========================================
    // AUTHENTICATION ROUTES
    // ==========================================

    // Register a new account
    Route::post('auth/register', [
        AuthController::class,
        'register',
    ]);

    // Login with rate limiting
    Route::post('auth/login', [
        AuthController::class,
        'login',
    ])->middleware('throttle:login');


    // ==========================================
    // PROTECTED ROUTES
    // ==========================================

    Route::middleware([
        'auth:sanctum',
        'active',
    ])->group(function () {

        // ======================================
        // USER ACCOUNT ROUTES
        // ======================================

        // Logout
        Route::post('auth/logout', [
            AuthController::class,
            'logout',
        ]);

        // Get user profile
        Route::get('me', [
            AuthController::class,
            'me',
        ]);

        // Update user profile
        Route::put('me', [
            AuthController::class,
            'update',
        ]);


        // ======================================
        // STUDENT ROUTES
        // ======================================

        Route::middleware('role:student')->group(function () {

            // ==================================
            // DASHBOARD / PROGRESS
            // ==================================

            Route::get('progress', [
                ProgressController::class,
                'show',
            ]);


            // ==================================
            // SUBJECT MANAGEMENT
            // ==================================

            // List, create, update, delete subjects
            Route::apiResource(
                'subjects',
                SubjectController::class
            )->except('show');


            // ==================================
            // TASK MANAGEMENT
            // ==================================

            // List, create, update, delete tasks
            Route::apiResource(
                'tasks',
                TaskController::class
            )->except('show');

            // Complete a task and award XP
            Route::post('tasks/{task}/complete', [
                TaskController::class,
                'complete',
            ])->name('tasks.complete');


            // ==================================
            // FOCUS SESSION MANAGEMENT
            // ==================================

            // Get focus session history
            Route::get('sessions', [
                FocusSessionController::class,
                'index',
            ])->name('sessions.index');

            // Get currently active or paused session
            Route::get('sessions/active', [
                FocusSessionController::class,
                'active',
            ])->name('sessions.active');

            // Start a new focus session
            Route::post('sessions', [
                FocusSessionController::class,
                'store',
            ])->name('sessions.store');

            // Pause an active focus session
            Route::patch('sessions/{session}/pause', [
                FocusSessionController::class,
                'pause',
            ])->name('sessions.pause');

            // Resume a paused focus session
            Route::patch('sessions/{session}/resume', [
                FocusSessionController::class,
                'resume',
            ])->name('sessions.resume');

            // Finish a focus session and award XP
            Route::patch('sessions/{session}/finish', [
                FocusSessionController::class,
                'finish',
            ])->name('sessions.finish');

            // Cancel a focus session without XP
            Route::patch('sessions/{session}/cancel', [
                FocusSessionController::class,
                'cancel',
            ])->name('sessions.cancel');

        });


        // ======================================
        // ADMIN ROUTES
        // ======================================

        // Admin routes will be implemented later.

    });

});
