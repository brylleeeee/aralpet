<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GamificationService;
use Illuminate\Http\Request;

class ProgressController extends Controller
{
    // GET /api/v1/progress
    public function show(Request $request, GamificationService $game)
    {
        return response()->json($game->snapshot($request->user()));
    }
}
