<?php

namespace App\Http\Controllers\report;

use App\Models\User;
use App\Models\Payments;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;

class financeController extends Controller
{
    public function finances(Request $request)
    {
        // Récupérer les données pour les filtres
        $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)->get();
        $caissiers = User::where('ets_id', auth()->user()->ets_id)
                        ->where('role', "caissier")
                        ->get();

        // Définir l'année courante par défaut
        $annee = $request->annee ?? now()->year;

        $baseQuery = Payments::with(['facture', 'emplacement', 'user'])
            ->where('ets_id', auth()->user()->ets_id);
    
        // Appliquer les filtres
        if ($request->emplacement_id) {
            $baseQuery->where('emplacement_id', $request->emplacement_id);
        }
        
        if ($request->caissier_id) {
            $baseQuery->where('user_id', $request->caissier_id);
        }
        
        if ($request->mode) {
            $baseQuery->where('mode', $request->mode);
        }
        
        if ($request->devise) {
            $baseQuery->where('devise', $request->devise);
        }
        
        if ($request->date_debut && $request->date_fin) {
            $baseQuery->whereBetween('pay_date', [$request->date_debut, $request->date_fin]);
        }

        // Récupérer les paiements pour l'affichage
        $paiements = $baseQuery->orderBy('pay_date', 'desc')->get();

        // Statistiques dynamiques basées sur les filtres
        $stats = [
            'total_recettes' => $paiements->sum('amount'),
            'total_paiements' => $paiements->count(),
            'recettes_aujourdhui' => (clone $baseQuery)->whereDate('pay_date', today())->sum('amount'),
            'recettes_semaine' => (clone $baseQuery)->whereBetween('pay_date', [
                now()->startOfWeek(), 
                now()->endOfWeek()
            ])->sum('amount'),
            'recettes_mois' => (clone $baseQuery)
                ->whereMonth('pay_date', now()->month)
                ->whereYear('pay_date', now()->year)
                ->sum('amount'),
        ];

        // Statistiques par devise (avec filtres)
        $stats_devises_query = Payments::where('ets_id', auth()->user()->ets_id);
        
        if ($request->emplacement_id) {
            $stats_devises_query->where('emplacement_id', $request->emplacement_id);
        }
        if ($request->caissier_id) {
            $stats_devises_query->where('user_id', $request->caissier_id);
        }
        if ($request->mode) {
            $stats_devises_query->where('mode', $request->mode);
        }
        if ($request->date_debut && $request->date_fin) {
            $stats_devises_query->whereBetween('pay_date', [$request->date_debut, $request->date_fin]);
        }
        
        $stats_devises = $stats_devises_query
            ->select('devise', DB::raw('SUM(amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->groupBy('devise')
            ->get();

        // Statistiques par mode de paiement (avec filtres)
        $stats_modes_query = Payments::where('ets_id', auth()->user()->ets_id);
        
        if ($request->emplacement_id) {
            $stats_modes_query->where('emplacement_id', $request->emplacement_id);
        }
        if ($request->caissier_id) {
            $stats_modes_query->where('user_id', $request->caissier_id);
        }
        if ($request->devise) {
            $stats_modes_query->where('devise', $request->devise);
        }
        if ($request->date_debut && $request->date_fin) {
            $stats_modes_query->whereBetween('pay_date', [$request->date_debut, $request->date_fin]);
        }
        
        $stats_modes = $stats_modes_query
            ->select('mode', DB::raw('SUM(amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->groupBy('mode')
            ->get();

        // Statistiques par emplacement (avec filtres)
        $stats_emplacements_query = Payments::join('emplacements', 'payments.emplacement_id', '=', 'emplacements.id')
            ->where('payments.ets_id', auth()->user()->ets_id);
            
        if ($request->caissier_id) {
            $stats_emplacements_query->where('payments.user_id', $request->caissier_id);
        }
        if ($request->mode) {
            $stats_emplacements_query->where('payments.mode', $request->mode);
        }
        if ($request->devise) {
            $stats_emplacements_query->where('payments.devise', $request->devise);
        }
        if ($request->date_debut && $request->date_fin) {
            $stats_emplacements_query->whereBetween('payments.pay_date', [$request->date_debut, $request->date_fin]);
        }
        
        $stats_emplacements = $stats_emplacements_query
            ->select('emplacements.libelle', 'emplacements.id', DB::raw('SUM(payments.amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->groupBy('emplacements.id', 'emplacements.libelle')
            ->get();

        // Statistiques par caissier (avec filtres)
        $stats_caissiers_query = Payments::join('users', 'payments.user_id', '=', 'users.id')
            ->where('payments.ets_id', auth()->user()->ets_id);
            
        if ($request->emplacement_id) {
            $stats_caissiers_query->where('payments.emplacement_id', $request->emplacement_id);
        }
        if ($request->mode) {
            $stats_caissiers_query->where('payments.mode', $request->mode);
        }
        if ($request->devise) {
            $stats_caissiers_query->where('payments.devise', $request->devise);
        }
        if ($request->date_debut && $request->date_fin) {
            $stats_caissiers_query->whereBetween('payments.pay_date', [$request->date_debut, $request->date_fin]);
        }
        
        $stats_caissiers = $stats_caissiers_query
            ->select('users.name', 'users.id', DB::raw('SUM(payments.amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->groupBy('users.id', 'users.name')
            ->get();

        // Évolution sur 12 mois
        $evolution_12mois = $this->getEvolution12Mois($annee, $request);

        // Statistiques de l'année
        $stats_annee = $this->getStatsAnnee($annee, $request);

        // Données pour les graphiques
        $graphique_modes = $stats_modes;
        $graphique_emplacements = $stats_emplacements;
        $graphique_devises = $stats_devises;

        return view('reports.finances', compact(
            'paiements',
            'stats',
            'stats_devises',
            'stats_modes',
            'stats_emplacements',
            'stats_caissiers',
            'evolution_12mois',
            'stats_annee',
            'graphique_modes',
            'graphique_emplacements',
            'graphique_devises',
            'annee',
            'emplacements',
            'caissiers'
        ));
    }

    private function getEvolution12Mois($annee, Request $request)
    {
        $query = Payments::where('ets_id', auth()->user()->ets_id)
            ->whereYear('pay_date', $annee);

        // Appliquer les mêmes filtres que la requête principale
        if ($request->filled('emplacement_id')) {
            $query->where('emplacement_id', $request->emplacement_id);
        }
        if ($request->filled('caissier_id')) {
            $query->where('user_id', $request->caissier_id);
        }
        if ($request->filled('mode')) {
            $query->where('mode', $request->mode);
        }
        if ($request->filled('devise')) {
            $query->where('devise', $request->devise);
        }
        if ($request->filled('date_debut') && $request->filled('date_fin')) {
            $query->whereBetween('pay_date', [$request->date_debut, $request->date_fin]);
        }

        $mois = $query->select(
            DB::raw('MONTH(pay_date) as mois'),
            DB::raw('SUM(amount) as total')
        )
        ->groupBy('mois')
        ->orderBy('mois')
        ->get();

        $evolution = collect();
        for ($i = 1; $i <= 12; $i++) {
            $moisData = $mois->firstWhere('mois', $i);
            $evolution->push([
                'mois' => $i,
                'mois_nom' => Carbon::create($annee, $i, 1)->locale('fr')->monthName,
                'total' => $moisData ? $moisData->total : 0
            ]);
        }

        return $evolution;
    }

    private function getStatsAnnee($annee, Request $request)
    {
        $query = Payments::where('ets_id', auth()->user()->ets_id)
            ->whereYear('pay_date', $annee);

        // Appliquer les mêmes filtres
        if ($request->filled('emplacement_id')) {
            $query->where('emplacement_id', $request->emplacement_id);
        }
        if ($request->filled('caissier_id')) {
            $query->where('user_id', $request->caissier_id);
        }
        if ($request->filled('mode')) {
            $query->where('mode', $request->mode);
        }
        if ($request->filled('devise')) {
            $query->where('devise', $request->devise);
        }
        if ($request->filled('date_debut') && $request->filled('date_fin')) {
            $query->whereBetween('pay_date', [$request->date_debut, $request->date_fin]);
        }

        $recettesAnnee = $query->sum('amount');
        $paiementsAnnee = $query->count();

        $mois = $query->select(
            DB::raw('MONTH(pay_date) as mois'),
            DB::raw('SUM(amount) as total')
        )
        ->groupBy('mois')
        ->orderBy('total', 'desc')
        ->get();

        $meilleurMois = $mois->first();
        $moinsBonMois = $mois->where('total', '>', 0)->last();

        return [
            'recettes_annee' => $recettesAnnee,
            'paiements_annee' => $paiementsAnnee,
            'moyenne_mensuelle' => $recettesAnnee > 0 ? $recettesAnnee / 12 : 0,
            'meilleur_mois' => $meilleurMois ? [
                'mois' => $meilleurMois->mois,
                'mois_nom' => Carbon::create($annee, $meilleurMois->mois, 1)->locale('fr')->monthName,
                'total' => $meilleurMois->total
            ] : ['mois_nom' => 'N/A', 'total' => 0],
            'moins_bon_mois' => $moinsBonMois ? [
                'mois' => $moinsBonMois->mois,
                'mois_nom' => Carbon::create($annee, $moinsBonMois->mois, 1)->locale('fr')->monthName,
                'total' => $moinsBonMois->total
            ] : ['mois_nom' => 'N/A', 'total' => 0],
        ];
    }

    public function getPaymentDetails($id)
    {
        $payment = Payments::with([
            'facture.details',
            'user',
            'emplacement',
            'table',
            'chambre',
            'saleDay'
        ])->where('id', $id)
          ->where('ets_id', auth()->user()->ets_id)
          ->firstOrFail();

        return response()->json([
            'success' => true,
            'payment' => $payment
        ]);
    }
}
