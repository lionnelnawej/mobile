<?php

namespace App\Http\Controllers\report;

use App\Models\Facture;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use App\Http\Controllers\Controller;

class CommandeController extends Controller
{
    public function index(Request $request)
    {
        $dateDebut = $request->input('date_debut');
        $dateFin = $request->input('date_fin');
        $emplacementId = $request->input('emplacement_id');
        $statut = $request->input('statut');
        $statutService = $request->input('statut_service');

        // Récupérer tous les emplacements pour le filtre
        $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->orderBy('libelle')
            ->where('type',"restaurant & lounge")
            ->get();

        // Query pour les commandes
        $query = Facture::with(['user', 'table', 'client', 'details.produit.categorie'])
            ->where('ets_id', auth()->user()->ets_id)
            ->whereIn('emplacement_id', $emplacements->pluck('id'))
            ->orderBy('date_facture', 'desc');

        // Appliquer les filtres
        if ($dateDebut) {
            $query->whereDate('date_facture', '>=', $dateDebut);
        }

        if ($dateFin) {
            $query->whereDate('date_facture', '<=', $dateFin);
        }

        if ($emplacementId) {
            $query->where('emplacement_id', $emplacementId);
        }

        if ($statut) {
            $query->where('statut', $statut);
        }

        if ($statutService) {
            $query->where('statut_service', $statutService);
        }

        $commandes = $query->paginate(20);

        // Calculer les statistiques
        $stats = $this->calculerStatsCommandes($query->get());

        return view('reports.commandesReport', compact(
            'commandes', 
            'emplacements', 
            'stats'
        ));
    }

    private function calculerStatsCommandes($commandes)
    {
        $totalCommandes = $commandes->count();
        
        // Répartition par statut
        $repartitionStatut = $commandes->groupBy('statut')->map->count();
        
        // Répartition par statut service
        $repartitionStatutService = $commandes->groupBy('statut_service')->map->count();
        
        // Délai moyen (si on a les données de préparation)
        $commandesTerminees = $commandes->where('statut_service', 'servie');
        $delaiMoyen = 30;
        
        if ($commandesTerminees->count() > 0) {
            // Ici vous devriez avoir un champ pour le temps de préparation
            // Pour l'exemple, on utilise une estimation
            $delaiMoyen = 25; // minutes en moyenne
        }

        // Commandes par heure
        $commandesParHeure = $commandes->groupBy(function($commande) {
            return Carbon::parse($commande->date_facture)->format('H');
        })->map->count();

        return [
            'total_commandes' => $totalCommandes,
            'repartition_statut' => $repartitionStatut,
            'repartition_statut_service' => $repartitionStatutService,
            'delai_moyen' => $delaiMoyen,
            'commandes_par_heure' => $commandesParHeure,
        ];
    }

    // API pour récupérer les détails d'une commande
    public function getCommandeDetails($commande_id)
    {
        $commande = Facture::with([
            'user', 
            'table.emplacement', 
            'chambre.emplacement',
            'client',
            'details.produit.categorie',
            'payments'
        ])->where('id', $commande_id)
          ->where('ets_id', auth()->user()->ets_id)
          ->firstOrFail();

        return response()->json([
            'success' => true,
            'commande' => $commande,
            'details' => $commande->details,
            'paiements' => $commande->payments
        ]);
    }
}
