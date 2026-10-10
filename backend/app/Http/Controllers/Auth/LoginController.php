<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AccessAllow;
use App\Models\User;
use Illuminate\Foundation\Auth\AuthenticatesUsers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class LoginController extends Controller
{
    /*
    |--------------------------------------------------------------------------
    | Login Controller
    |--------------------------------------------------------------------------
    |
    | This controller handles authenticating users for the application and
    | redirecting them to your home screen. The controller uses a trait
    | to conveniently provide its functionality to your applications.
    |
    */

    use AuthenticatesUsers;

    /**
     * Where to redirect users after login.
     *
     * @var string
     */
    protected $redirectTo = '/';

    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        $this->middleware('guest')->except('logout');
        $this->middleware('auth')->only('logout');
    }


    public function login(Request $request)
    {
        // 1️⃣ Validation
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        // 2️⃣ Vérifier si la journée est autorisée
        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json(['errors' => 'Identifiants invalides']);
        }

        $access = AccessAllow::where("ets_id", $user->ets_id)->latest()->first();
        $isAllowed = $access ? $access->allowed : false;

        // 3️⃣ Bloquer la connexion si journée non autorisée et non admin
        if (!$isAllowed && !$user->hasRole('admin') && !$user->hasRole('caissier')) {
            return response()->json([
                'alerts' => 'La journée n\'est pas ouverte.'
            ]);
        }

        // 4️⃣ Tentative de connexion
        if (Auth::attempt(['email' => $request->email, 'password' => $request->password], $request->filled('remember'))) {
            // 5️⃣ Redirection selon rôle
            return response()->json([
                "user"=>$user,
                "redirect"=>$user->role === 'serveur' ? route('orders.portal') : "/"
            ]);
        }
        return response()->json(['errors' => 'Identifiants invalides']);
    }
}
