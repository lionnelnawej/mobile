<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\AccessAllow;

class CheckDayAccess
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Illuminate\Http\Response|\Illuminate\Http\RedirectResponse)  $next
     * @return \Illuminate\Http\Response|\Illuminate\Http\RedirectResponse
     */
    public function handle(Request $request, Closure $next)
    {
        if (!Auth::check()) {
            return redirect()->route('login');
        }
        $user = Auth::user();
        $access = AccessAllow::where("ets_id", $user->ets_id)->latest()->first();

        if ($access && !$access->allowed && !$user->hasRole('admin') && !$user->hasRole('caissier')) {
            Auth::logout();
            return redirect()->route('login')->withErrors([
                'message' => 'La journée n\'est pas encore lancée.'
            ]);
        }
        return $next($request);
    }
}
