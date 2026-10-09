<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tycoon_scores', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 32);
            $table->string('role', 20);
            $table->string('pseudo', 20);
            $table->unsignedBigInteger('score')->default(0);
            $table->timestamps();

            $table->unique(['device_id', 'role']);
            $table->index(['role', 'score']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tycoon_scores');
    }
};
