<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('xp_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('source_type');                   // session or task
            $table->unsignedBigInteger('source_id');
            $table->unsignedInteger('amount');
            $table->date('earned_on');                       // Manila date, for the daily cap
            $table->timestamps();

            $table->unique(['source_type', 'source_id']);    // blocks double XP
            $table->index(['user_id', 'earned_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('xp_ledger');
    }
};