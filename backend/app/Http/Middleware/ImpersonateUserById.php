<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\User;

class ImpersonateUserById
{
    /**
     * If request contains user_id, set the Auth user to that user so
     * controllers using Auth::user() will work with either tokens or user_id.
     */
    public function handle(Request $request, Closure $next)
    {
        $userId = $request->input('user_id') ?? $request->header('X-User-Id');
        if ($userId) {
            $user = User::find((int)$userId);
            if ($user) {
                // Set the current authenticated user for the duration of the request
                Auth::setUser($user);
            }
        }

        return $next($request);
    }
}
