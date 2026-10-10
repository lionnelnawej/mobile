<?php

namespace App\Providers;

use App\Models\AccessAllow;
use App\Models\Licence;
use App\Models\SaleDay;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Blade;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        //
    }

    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {
        \Carbon\Carbon::setLocale("fr");
        Blade::directive('active', function ($routes) {
            return "<?php
                \$activeClasses = [];
                foreach ((array) {$routes} as \$route) {
                    if (Route::is(\$route)) {
                        \$activeClasses[] = 'active';
                    }
                }
                echo implode(' ', array_unique(\$activeClasses));
            ?>";
        });

        Blade::if('canCloseDay', function () {
            $todaySale = SaleDay::whereNull('end_time')->where("ets_id", Auth::user()->ets_id)->latest('start_time')->first();
            $accessAllowed = AccessAllow::first()?->allowed ?? false;
            return $todaySale && $accessAllowed;
        });

        Blade::directive("lastRate", function(){
            return "<?php echo \\App\\Models\\Currencie::where('ets_id', Auth::user()->ets_id)->latest('id')->value('currencie_value') ?? 0; ?>";
        });


        Blade::if('licenceActive', function () {
            $user = Auth::user();
            if (!$user || !$user->etablissement || !$user->etablissement->licence) {
                return false; // pas de licence → bloqué
            }
            $licence = Licence::where("ets_id", $user->ets_id)->first();
            // Vérifie si la licence est encore valide
            return $licence->status === 'available' && now()->lessThanOrEqualTo($licence->date_fin);
        });

    }
}
