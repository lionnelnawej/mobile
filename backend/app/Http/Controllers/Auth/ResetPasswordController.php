<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Foundation\Auth\ResetsPasswords;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Password;

class ResetPasswordController extends Controller
{
    use ResetsPasswords;

    protected $redirectTo = '/'; // redirection après reset

    // Surcharge de la méthode reset pour vérifier le rôle
    public function reset(Request $request)
    {
        // Validation standard
        $request->validate($this->rules(), $this->validationErrorMessages());

        // Vérifier que l'utilisateur existe et est admin
        $user = User::where('email', $request->email)->first();

        if (!$user || $user->role !== 'admin') {
            return redirect()->route('password.request')
                             ->withErrors(['email' => "Impossible de réinitialiser ce compte."]);
        }

        // Si tout est ok, appeler la logique du trait
        return $this->resetPasswordForTrait($request, $user);
    }

    // Méthode privée pour appeler la logique originale du trait
    protected function resetPasswordForTrait(Request $request, User $user)
    {
        // Récupération du token
        $credentials = $request->only('email', 'password', 'password_confirmation', 'token');

        $status = Password::reset($credentials, function ($user, $password) {
            $this->resetPassword($user, $password); // méthode du trait ResetsPasswords
        });

        return $status === Password::PASSWORD_RESET
            ? redirect($this->redirectPath())->with('status', __($status))
            : back()->withErrors(['email' => [__($status)]]);
    }
}