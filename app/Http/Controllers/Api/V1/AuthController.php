<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    // POST /api/v1/auth/register
    public function register(Request $request)
    {
        $data = $request->validate([
            'name'        => ['required', 'string', 'max:100'],
            'email'       => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password'    => ['required', 'confirmed', Password::min(8)],
            'course'      => ['nullable', 'string', 'max:100'],
            'year_level'  => ['nullable', 'integer', 'between:1,6'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        // Account, progress record and egg pet are created together, or not at all
        $user = DB::transaction(function () use ($data) {
            $user = new User([
                'name'       => $data['name'],
                'email'      => $data['email'],
                'password'   => $data['password'],   // hashed by the User model
                'course'     => $data['course'] ?? null,
                'year_level' => $data['year_level'] ?? null,
            ]);
            $user->role = 'student';                 // never taken from the request
            $user->is_active = true;
            $user->save();

            $user->progress()->create();
            $user->pet()->create(['name' => 'Aral', 'stage' => 'egg']);

            return $user;
        });

        $token = $user->createToken($data['device_name'] ?? 'mobile')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user'  => new UserResource($user),
            ],
        ], 201);
    }

    // POST /api/v1/auth/login   (rate-limited: 5 per minute)
    public function login(Request $request)
    {
        $data = $request->validate([
            'email'       => ['required', 'string', 'email'],
            'password'    => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (! $user->is_active) {
            return response()->json(['message' => 'Account is deactivated.'], 403);
        }

        $token = $user->createToken($data['device_name'] ?? 'mobile')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user'  => new UserResource($user),
            ],
        ]);
    }

    // POST /api/v1/auth/logout
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();   // 204
    }

    // GET /api/v1/me
    public function me(Request $request)
    {
        return new UserResource($request->user());
    }

    // PUT /api/v1/me
    public function update(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'name'             => ['sometimes', 'required', 'string', 'max:100'],
            'course'           => ['sometimes', 'nullable', 'string', 'max:100'],
            'year_level'       => ['sometimes', 'nullable', 'integer', 'between:1,6'],
            'password'         => ['sometimes', 'confirmed', Password::min(8)],
            'current_password' => ['required_with:password', 'current_password:sanctum'],
        ]);

        $user->fill(collect($data)->only(['name', 'course', 'year_level'])->all());

        if (isset($data['password'])) {
            $user->password = $data['password'];

            // Sign out every other device after a password change
            $user->tokens()
                ->where('id', '!=', $user->currentAccessToken()->id)
                ->delete();
        }

        $user->save();

        return new UserResource($user);
    }
}