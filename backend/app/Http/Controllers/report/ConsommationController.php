<?php

namespace App\Http\Controllers\report;

use App\Models\Payments;
use App\Models\Emplacement;
use App\Models\User;
use App\Models\Facture;
use App\Models\SaleDay;
use Illuminate\Http\Request;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ConsommationController extends Controller
{
    public function finances(Request $request)
    {
        // Récupérer les données pour les filtres
        $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)->get();
        $caissiers = User::where('ets_id', auth()->user()->ets_id)
                        ->where('actif', true)
                        ->get();

        // Query de base pour les paiements
        $query = Payments::with(['emplacement', 'user', 'facture', 'saleDay'])
            ->where('ets_id', auth()->user()->ets_id);

        // Appliquer les filtres
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

        // Filtre par période
        $annee = $request->filled('annee') ? $request->annee : now()->year;
        
        if ($request->filled('date_debut') && $request->filled('date_fin')) {
            $query->whereBetween('pay_date', [
                $request->date_debut,
                Carbon::parse($request->date_fin)->endOfDay()
            ]);
        } else {
            // Par défaut, année en cours
            $query->whereYear('pay_date', $annee);
        }

        // Pagination pour les détails
        $paiements = $query->orderBy('pay_date', 'desc')->paginate(50);

        // Statistiques principales
        $stats = [
            'total_recettes' => $query->sum('amount'),
            'total_paiements' => $query->count(),
            'recettes_aujourdhui' => Payments::where('ets_id', auth()->user()->ets_id)
                ->whereDate('pay_date', today())
                ->sum('amount'),
            'recettes_semaine' => Payments::where('ets_id', auth()->user()->ets_id)
                ->whereBetween('pay_date', [
                    now()->startOfWeek(),
                    now()->endOfWeek()
                ])->sum('amount'),
            'recettes_mois' => Payments::where('ets_id', auth()->user()->ets_id)
                ->whereMonth('pay_date', now()->month)
                ->whereYear('pay_date', now()->year)
                ->sum('amount'),
        ];

        // Statistiques par devise
        $stats_devises = Payments::select('devise', DB::raw('SUM(amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->where('ets_id', auth()->user()->ets_id)
            ->groupBy('devise')
            ->get();

        // Statistiques par mode de paiement
        $stats_modes = Payments::select('mode', DB::raw('SUM(amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->where('ets_id', auth()->user()->ets_id)
            ->groupBy('mode')
            ->get();

        // Statistiques par emplacement
        $stats_emplacements = Payments::join('emplacements', 'payments.emplacement_id', '=', 'emplacements.id')
            ->select('emplacements.libelle', 'emplacements.id', DB::raw('SUM(payments.amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->where('payments.ets_id', auth()->user()->ets_id)
            ->groupBy('emplacements.id', 'emplacements.libelle')
            ->get();

        // Statistiques par caissier
        $stats_caissiers = Payments::join('users', 'payments.user_id', '=', 'users.id')
            ->select('users.name', 'users.id', DB::raw('SUM(payments.amount) as total'), DB::raw('COUNT(*) as nombre'))
            ->where('payments.ets_id', auth()->user()->ets_id)
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