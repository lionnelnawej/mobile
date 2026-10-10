<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use App\Models\User;

class ForgotPasswordController extends Controller
{
    public function sendResetLinkEmail(Request $request)
    {
        $request->validate(['email' => 'required|email']);

        $user = User::where('email', $request->email)->first();

        // Option 1 — réponse claire (s'affiche une erreur si non-admin)
        if (!$user || $user->role !== 'admin') {
            return back()->withErrors(['email' => "Aucun administrateur trouvé avec cette adresse e-mail."]);
        }
        // Envoi du lien (Laravel utilisera maintenant ta notification custom via User::sendPasswordResetNotification)
        $status = Password::sendResetLink($request->only('email'));

        return $status === Password::RESET_LINK_SENT
            ? back()->with(['status' => __($status)])
            : back()->withErrors(['email' => __($status)]);
    }


    public function showLinkRequestForm()
    {
        return view('auth.passwords.email'); // ta Blade pour l'email
    }
}
