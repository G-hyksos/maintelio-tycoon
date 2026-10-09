<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TycoonScore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Classement en ligne de Maintelio Tycoon.
 *
 * GET  /api/tycoon/leaderboard?role=chefSite  → 50 meilleurs scores du rôle
 * POST /api/tycoon/scores                      → enregistre le meilleur score d'un appareil
 */
class TycoonLeaderboardController extends Controller
{
    private const ROLES = ['gestionnaire', 'dirigeant', 'chefSite', 'adjoint', 'technicien'];

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['required', Rule::in(self::ROLES)],
        ]);

        $rows = TycoonScore::query()
            ->where('role', $validated['role'])
            ->orderByDesc('score')
            ->orderBy('updated_at')
            ->limit(50)
            ->get(['pseudo', 'score']);

        return response()->json(['data' => $rows]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => ['required', 'string', 'size:32', 'regex:/^[a-f0-9]+$/'],
            'pseudo' => ['required', 'string', 'min:3', 'max:20'],
            'role' => ['required', Rule::in(self::ROLES)],
            'score' => ['required', 'integer', 'min:0', 'max:100000000'],
        ]);

        $entry = TycoonScore::firstOrNew([
            'device_id' => $validated['device_id'],
            'role' => $validated['role'],
        ]);
        $entry->pseudo = trim(strip_tags($validated['pseudo']));
        $entry->score = max((int) $entry->score, (int) $validated['score']);
        $entry->save();

        return response()->json([
            'data' => ['pseudo' => $entry->pseudo, 'score' => $entry->score],
        ], 201);
    }
}
