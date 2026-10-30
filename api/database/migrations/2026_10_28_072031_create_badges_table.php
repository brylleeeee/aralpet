<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('badges', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();                // e.g. first_focus, streak_7
            $table->string('name');
            $table->string('description');
            $table->string('icon')->nullable();
            $table->string('condition_type');                // e.g. streak, tasks_completed, level
            $table->unsignedInteger('threshold');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('badges');
    }
};