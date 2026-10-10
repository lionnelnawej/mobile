<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

class UserActionLogger 
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
        $response = $next($request);

        // ne logger que si l'utilisateur est connecté
        if (!Auth::check()) {
            return $response;
        }

        // ne logger que les méthodes qui modifient le système
        if (!in_array($request->method(), ['POST','PUT','PATCH','DELETE'])) {
            return $response;
        }

        // ne logger que les réponses "réussies" (2xx)
        $status = $response->getStatusCode();
        if ($status < 200 || $status >= 300) {
            return $response;
        }

        $routeName = Route::currentRouteName();
        $action    = Route::currentRouteAction(); // Controller@method
        $description = $this->getActionDescription($routeName, $action);

        $logDir = storage_path('logs/user_actions');
        if (!File::exists($logDir)) {
            File::makeDirectory($logDir, 0755, true);
        }

        $logFile = $logDir . '/user_actions.txt';

        $entry = [
            'timestamp'   => now()->toDateTimeString(),
            'user_id'     => Auth::id(),
            'user_name'   => Auth::user()->name ?? Auth::user()->email ?? 'unknown',
            'method'      => $request->method(),
            'route'       => $routeName,
            'action'      => $action,
            'description' => $description,
            'ip'          => $request->ip(),
            'status'      => $status,
            // 'payload'   => $request->except(['password','password_confirmation','_token','_method']) // optionnel
        ];

        File::append($logFile, json_encode($entry, JSON_UNESCAPED_UNICODE) . PHP_EOL);
        return $response;
    }

    private function getActionDescription($routeName, $action)
    {
        $map = [
            'visit.create'   => 'Création ou mise à jour d\'une visite',
            'user_create'    => 'Création d\'un nouvel utilisateur',
            'config.create'  => 'Ajout ou modification d\'un paramètre système',
            'delete'         => 'Suppression d\'un élément',
            'login'         => 'Connexion',
            'logout'         => 'Deconnexion',
            // Ajoute ici d'autres mappings
        ];

        if ($routeName && isset($map[$routeName])) {
            return $map[$routeName];
        }

        // fallback : dériver depuis le controller@method
        if ($action) {
            return 'Action contrôleur: ' . $action;
        }

        return 'Action non spécifiée';
    }
}
