<?php

namespace App\Http\Controllers\report;

use App\Models\Facture;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use App\Models\FactureDetail;
use App\Http\Controllers\Controller;

class ProduitController extends Controller
{
    public function index()
    {
       $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->orderBy('libelle')
            ->where('type',"restaurant & lounge")
            ->get();

        return view('reports.produitsPlusVendus', compact('emplacements'));
    }
   public function showProduitsPlusVendus($emplacement_id)
    {
        $emplacement = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->where('id', $emplacement_id)
            ->where('type',"restaurant & lounge")
            ->first();
            
        if (!$emplacement) {
            return redirect()->route('reports.produits.plusVendus')->with('error', 'Cet emplacement n\'existe pas.');
        }

        // Récupérer les produits les plus vendus pour cet emplacement
        $produitsVendus = $this->getProduitsPlusVendusParEmplacement($emplacement);

        return view('reports.produitPlusVenduDetails', compact('emplacement', 'produitsVendus'));
    }

    private function getProduitsPlusVendusParEmplacement($emplacement)
    {
        // Récupérer toutes les factures payées pour cet emplacement
        // Utilisation directe du champ emplacement_id dans Facture
        $factures = Facture::where('statut', 'payée')
            ->where('emplacement_id', $emplacement->id)
            ->where('ets_id', auth()->user()->ets_id)
            ->with(['details.produit.categorie', 'payments'])
            ->get();

        // Compiler les statistiques des produits
        $produitsStats = [];
        $devisePrincipale = 'CDF';

        foreach ($factures as $facture) {
            // Récupérer la devise
            if ($facture->payments->isNotEmpty() && $devisePrincipale === 'CDF') {
                $devisePrincipale = $facture->payments->first()->devise ?? 'CDF';
            }

            foreach ($facture->details as $detail) {
                $produitId = $detail->produit_id;
                
                if (!isset($produitsStats[$produitId])) {
                    $produitsStats[$produitId] = [
                        'produit' => $detail->produit,
                        'quantite_vendue' => 0,
                        'chiffre_affaires' => 0,
                        'nombre_factures' => 0,
                        'factures_ids' => []
                    ];
                }

                $produitsStats[$produitId]['quantite_vendue'] += $detail->quantite;
                $produitsStats[$produitId]['chiffre_affaires'] += $detail->total_ligne;
                
                // Compter le nombre de factures uniques pour ce produit
                if (!in_array($facture->id, $produitsStats[$produitId]['factures_ids'])) {
                    $produitsStats[$produitId]['factures_ids'][] = $facture->id;
                    $produitsStats[$produitId]['nombre_factures']++;
                }
            }
        }

        // Trier par quantité vendue (décroissant)
        usort($produitsStats, function($a, $b) {
            return $b['quantite_vendue'] - $a['quantite_vendue'];
        });

        return [
            'produits' => $produitsStats,
            'devise' => $devisePrincipale,
            'total_factures' => $factures->count(),
            'total_produits_vendus' => array_sum(array_column($produitsStats, 'quantite_vendue')),
            'chiffre_affaires_total' => $factures->sum('total_ttc')
        ];
    }

    // Méthode alternative avec requête plus optimisée
    private function getProduitsPlusVendusOptimise($emplacement)
    {
        // Version optimisée avec requête directe
        $produitsStats = FactureDetail::join('factures', 'facture_details.facture_id', '=', 'factures.id')
            ->join('produits', 'facture_details.produit_id', '=', 'produits.id')
            ->leftJoin('categories', 'produits.categorie_id', '=', 'categories.id')
            ->where('factures.statut', 'payée')
            ->where('factures.emplacement_id', $emplacement->id)
            ->where('factures.ets_id', auth()->user()->ets_id)
            ->selectRaw('
                produits.id,
                produits.libelle as produit_libelle,
                produits.reference as produit_reference,
                produits.code_barre as produit_code_barre,
                categories.libelle as categorie_libelle,
                SUM(facture_details.quantite) as quantite_vendue,
                SUM(facture_details.total_ligne) as chiffre_affaires,
                COUNT(DISTINCT factures.id) as nombre_factures
            ')
            ->groupBy('produits.id', 'produits.libelle', 'produits.reference', 'produits.code_barre', 'categories.libelle')
            ->orderByDesc('quantite_vendue')
            ->get();

        // Récupérer la devise principale
        $factureExemple = Facture::where('emplacement_id', $emplacement->id)
            ->where('statut', 'payée')
            ->where('ets_id', auth()->user()->ets_id)
            ->with('payments')
            ->first();
        
        $devisePrincipale = $factureExemple && $factureExemple->payments->isNotEmpty() 
            ? $factureExemple->payments->first()->devise 
            : 'CDF';

        // Statistiques globales
        $totalFactures = Facture::where('emplacement_id', $emplacement->id)
            ->where('statut', 'payée')
            ->where('ets_id', auth()->user()->ets_id)
            ->count();

        $chiffreAffairesTotal = Facture::where('emplacement_id', $emplacement->id)
            ->where('statut', 'payée')
            ->where('ets_id', auth()->user()->ets_id)
            ->sum('total_ttc');

        $totalProduitsVendus = $produitsStats->sum('quantite_vendue');

        return [
            'produits' => $produitsStats,
            'devise' => $devisePrincipale,
            'total_factures' => $totalFactures,
            'total_produits_vendus' => $totalProduitsVendus,
            'chiffre_affaires_total' => $chiffreAffairesTotal
        ];
    }
}

