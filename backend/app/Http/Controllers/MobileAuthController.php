<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class MobileAuthController extends Controller
{
    /**
     * Mobile login by user_id only. Creates a Sanctum token and returns user info.
     * Expects { user_id: int }
     */
    public function loginMobile(Request $request)
    {
        $data = $request->validate([
            'user_id' => 'required|int|exists:users,id'
        ]);

        $user = User::find($data['user_id']);
        if (!$user) {
            return response()->json(['errors' => 'Utilisateur introuvable'], 404);
        }

        // Optionally create a personal access token (Sanctum)
        if (method_exists($user, 'createToken')) {
            $token = $user->createToken('mobile')->plainTextToken;
        } else {
            $token = null;
        }

        // Load establishment info and return user info and token
        $user->load('etablissement');

        return response()->json([
            'status' => 'success',
            'user' => $user,
            'etablissement' => $user->etablissement,
            'token' => $token,
        ]);
    }

    /**
     * Mobile login by email + password. Returns user and token.
     * Expects { email: string, password: string }
     */
    public function loginEmail(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string'
        ]);

        $user = User::where('email', $data['email'])->first();
        if (!$user || !Hash::check($data['password'], $user->password)) {
            return response()->json(['errors' => 'Identifiants invalides'], 401);
        }

        // Create token if possible
        if (method_exists($user, 'createToken')) {
            $token = $user->createToken('mobile')->plainTextToken;
        } else {
            $token = null;
        }

        $user->load('etablissement');

        return response()->json([
            'status' => 'success',
            'user' => $user,
            'etablissement' => $user->etablissement,
            'token' => $token,
        ]);
    }
}
