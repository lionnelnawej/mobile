<?php

namespace App\Console;

use App\Models\Licence;
use App\Models\LicencePayRequest;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;
use Illuminate\Support\Facades\Http;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     *
     * @param  \Illuminate\Console\Scheduling\Schedule  $schedule
     * @return void
     */
    protected function schedule(Schedule $schedule)
    {
        $schedule->command('reservations:update')->dailyAt('00:05');
        // $schedule->command('inspire')->hourly();
        // Verifie l'expiration d'une licence en cours
        $schedule->call(function () {
            Licence::where('status', 'available')
                ->where('date_fin', '<', now())
                ->update(['status' => 'expired']);
        })->daily(); 


        //Permet de modifier le status de paiement pour valider l'activation de la licence
        /*$schedule->call(function () {
            $pendingRequests = LicencePayRequest::where('status', 'pending')
                                ->orderByDesc('created_at')
                                ->get();
            foreach ($pendingRequests as $request) {
                try {
                    // Interroger l'API du fournisseur
                    $response = Http::get("https://payment.milleniumhorizon.com/status", [
                        'uuid' => $request->uuid
                    ]);

                    if ($response->ok() && $response->json('status') === 'valid') {

                        // Mettre à jour la pay_request
                        $request->update(['status' => 'valid']);

                        // Mettre à jour la licence correspondante
                        $licence = Licence::where('ets_id', $request->ets_id)->latest()->first();

                        if ($licence) {
                            $licence->update([
                                'type' => 'paid',
                                'status' => 'available',
                                'date_debut' => now(),
                                'date_fin' => now()->addMonth()
                            ]);
                        }
                    }
                } catch (\Exception $e) {
                    // Log les erreurs pour debug
                    \Log::error("Erreur lors de la vérification du paiement UUID {$request->uuid}: " . $e->getMessage());
                }
            }
        })->everyMinute();*/
    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
