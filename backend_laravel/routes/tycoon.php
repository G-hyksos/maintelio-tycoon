<?php

// À inclure depuis routes/api.php : require __DIR__.'/tycoon.php';
// Les routes sont alors servies sous /api/tycoon/...

use App\Http\Controllers\Api\TycoonLeaderboardController;
use Illuminate\Support\Facades\Route;

Route::prefix('tycoon')
    ->middleware('throttle:30,1')
    ->group(function () {
        Route::get('leaderboard', [TycoonLeaderboardController::class, 'index']);
        Route::post('scores', [TycoonLeaderboardController::class, 'store']);
    });
