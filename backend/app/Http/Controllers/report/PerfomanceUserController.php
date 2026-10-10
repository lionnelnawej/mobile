<?php

namespace App\Http\Controllers\report;

use App\Models\User;
use App\Models\Facture;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class PerfomanceUserController extends Controller
{
    public function index(Request $request)
    {
         $dateDebut = $request->input('date_debut');
        $dateFin = $request->input('date_fin');
        $emplacementId = $request->input('emplacement_id');
        $role = $request->input('role');

        // Récupérer tous les emplacements pour le filtre
        $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->orderBy('libelle')
            ->where('type',"restaurant & lounge")
            ->get();

        // Récupérer TOUS les employés (actifs et inactifs) avec filtres
        $query = User::where('ets_id', auth()->user()->ets_id)
            ->where('role',"serveur")
            ->with(['emplacement']);

        if ($emplacementId) {
            $query->where('emplacement_id', $emplacementId);
        }

        if ($role) {
            $query->where('role', $role);
        }

        $employes = $query->get();

        // Calculer les performances pour chaque employé
        $performances = [];
        $totalCommandesGlobal = 0;
        $totalEncaissementGlobal = 0;

        foreach ($employes as $employe) {
            // Query pour les factures de l'employé
            $facturesQuery = Facture::where('user_id', $employe->id)
                ->where('statut', 'payée')
                ->with(['payments']);

            // Appliquer les filtres de date
            if ($dateDebut) {
                $facturesQuery->whereDate('date_facture', '>=', $dateDebut);
            }

            if ($dateFin) {
                $facturesQuery->whereDate('date_facture', '<=', $dateFin);
            }

            $factures = $facturesQuery->get();

            $nombreCommandes = $factures->count();
            $totalEncaissement = $factures->sum('total_ttc');
            
            // Calculer le panier moyen
            $panierMoyen = $nombreCommandes > 0 ? $totalEncaissement / $nombreCommandes : 0;

            // Déterminer la devise principale (CDF par défaut)
            $devisePrincipale = 'CDF';
            if ($factures->isNotEmpty()) {
                $premiereFacture = $factures->first();
                if ($premiereFacture->payments->isNotEmpty()) {
                    $devisePrincipale = $premiereFacture->payments->first()->devise ?? 'CDF';
                }
            }

            // Calculer le pourcentage de performance (basé sur le CA moyen)
            $pourcentagePerformance = 0;
            if ($panierMoyen > 0) {
                // Logique de calcul de performance ajustée
                $pourcentagePerformance = min(100, ($panierMoyen / 50000) * 100); // Ajusté pour CDF
            }

            $performances[] = [
                'employe' => $employe,
                'nombre_commandes' => $nombreCommandes,
                'total_encaissement' => $totalEncaissement,
                'panier_moyen' => $panierMoyen,
                'devise_principale' => $devisePrincipale,
                'pourcentage_performance' => $pourcentagePerformance,
                'est_actif' => $employe->actif,
            ];

            $totalCommandesGlobal += $nombreCommandes;
            $totalEncaissementGlobal += $totalEncaissement;
        }

        // Trier par performance (total encaissement décroissant)
        usort($performances, function($a, $b) {
            return $b['total_encaissement'] - $a['total_encaissement'];
        });
        $totalEmployes = $employes->count();
        $totalCommandes = $totalCommandesGlobal;
        $totalEncaissement = $totalEncaissementGlobal;
        return view('reports.performance', compact(
            'performances',
            'emplacements',
            'totalEmployes',
            'totalCommandes',
            'totalEncaissement'
        ));
    }
}
