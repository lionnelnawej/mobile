<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\Etablissement;
use App\Models\User;
use Illuminate\Foundation\Auth\RegistersUsers;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Spatie\Permission\Models\Role;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
class RegisterController extends Controller
{
    /*
    |--------------------------------------------------------------------------
    | Register Controller
    |--------------------------------------------------------------------------
    |
    | This controller handles the registration of new users as well as their
    | validation and creation. By default this controller uses a trait to
    | provide this functionality without requiring any additional code.
    |
    */

    use RegistersUsers;

    /**
     * Where to redirect users after registration.
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
        $this->middleware('guest');
    }
     /**
     * Enregistrement d'un nouvel utilisateur avec connexion automatique
     */
    public function register(Request $request)
    {
        // 1️⃣ Validation
        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'string', 'confirmed'],
            'telephone' => ['required', 'string', 'min:10'],
            'nom' => ['required', 'string', 'max:255'],
            'type' => ['required', 'string', 'max:255'],
            'adresse' => ['required', 'string', 'max:255'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'errors' => $validator->errors(),
            ]);
        }

        DB::beginTransaction();

        try {
            // 2️⃣ Création de l’établissement
            $etablissement = Etablissement::create([
                'nom' => $request->nom,
                'type' => $request->type,
                'adresse' => $request->adresse,
                'telephone' => $request->telephone,
            ]);

            // 3️⃣ Création de l’utilisateur admin
            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'actif' => true,
                'role' => 'admin',
                'etablissement_id' => $etablissement->id,
            ]);

            // 4️⃣ Attribution du rôle admin via Spatie
            $roleAdmin = Role::firstOrCreate(['name' => 'admin']);
            $user->assignRole($roleAdmin);

            // 5️⃣ Connexion automatique
            Auth::login($user);

            DB::commit();

            // 6️⃣ Détermination de la redirection selon le rôle
            $redirect = '/';

            // ✅ Réponse JSON
            return response()->json([
                'message' => 'Utilisateur et établissement créés avec succès. Connexion effectuée.',
                'user' => $user,
                'redirect' => $redirect,
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'errors' => $e->getMessage(),
            ]);
        }
    }
}
