<?php

namespace App\Http\Controllers\Product;

use Exception;
use App\Models\Produit;
use App\Models\Categorie;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use App\Models\FactureDetail;
use App\Models\MouvementStock;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Http\Controllers\Controller;

class ProduitsController extends Controller
{
    public function supprimer(Request $request)
{
    $request->validate([
        'id' => 'required|exists:produits,id'
    ]);

    try {
        DB::beginTransaction();

        $produit = Produit::findOrFail($request->id);

        // Calculer le stock actuel
        $stockActuel = $this->calculerStockProduit($produit->id);
        
        // Vérifier si le stock est à 0 ou moins
        if ($stockActuel > 0) {
            return response()->json([
                'status' => 'error',
                'message' => "Impossible de supprimer. Stock actuel: {$stockActuel}"
            ], 422);
        }

        // Supprimer les mouvements de stock associés
        MouvementStock::where('produit_id', $produit->id)->delete();

        // Supprimer les inventaires associés
        if (method_exists($produit, 'inventaires')) {
            $produit->inventaires()->delete();
        }

        // Supprimer le produit
        $produit->delete();

        DB::commit();

        return response()->json([
            'status' => 'success',
            'message' => 'Produit supprimé avec succès'
        ]);

    } catch (\Exception $e) {
        DB::rollBack();
        
        return response()->json([
            'status' => 'error',
            'message' => 'Erreur lors de la suppression'
        ], 500);
    }
}

/**
 * Calcule le stock actuel du produit
 */
private function calculerStockProduit($produitId)
{
    try {
        $produit = Produit::find($produitId);
        if (!$produit) {
            return 0;
        }

        // Commencer avec le stock initial
        $stock = $produit->qte_init ?? 0;

        // Récupérer tous les mouvements de stock
        $mouvements = MouvementStock::where('produit_id', $produitId)->get();
        
        foreach ($mouvements as $mouvement) {
            switch ($mouvement->type_mouvement) {
                case 'entree':
                case 'inventaire_plus':
                case 'ajustement_plus':
                    $stock += $mouvement->quantite;
                    break;
                
                case 'sortie':
                case 'inventaire_moins':
                case 'ajustement_moins':
                case 'vente':
                    $stock -= $mouvement->quantite;
                    break;
                
                // Les transferts ne changent pas le stock global
                case 'transfert':
                    break;
            }
        }
        
        return max(0, $stock); // Le stock ne peut pas être négatif
        
    } catch (\Exception $e) {
        return 0;
    }
}
public function approvisionnements()
{
    $produits = Produit::with(['categorie', 'emplacement', 'stocks'])->get();
        $categories = Categorie::all();
        $emplacements = Emplacement::all();
        
        return view('products.approvisionnements', compact('produits', 'categories', 'emplacements'));
    }

    public function createApprovisionnement(Request $request)
    {
        $request->validate([
            'items' => 'required|array|min:1',
            'items.*.produit_id' => 'required|exists:produits,id',
            'items.*.quantite' => 'required|integer|min:1',
            'items.*.prix_unitaire' => 'required|numeric|min:0'
        ]);

        try {
            DB::beginTransaction();

            $user = auth()->user();

            foreach ($request->items as $item) {
                $produit = Produit::find($item['produit_id']);
                MouvementStock::create([
                    'produit_id' => $item['produit_id'],
                    'type_mouvement' => 'entree',
                    'quantite' => $item['quantite'],
                    'source' => $item['produit_id'],
                    'destination' => $produit->emplacement_id, // Emplacement du produit
                    'date_mouvement' => now(),
                    'user_id' => $user->id,
                    'ets_id' => $user->ets_id,
                    'emplacement_id' => $produit->emplacement_id, // Emplacement du produit
                    'numdoc' => 'APPROV_' . now()->format('YmdHis')
                ]);

                // Mettre à jour le prix du produit
                if ($item['prix_unitaire'] > 0) {
                    $produit->prix_unitaire = $item['prix_unitaire'];
                    $produit->save();
                }
            }

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Approvisionnement enregistré avec succès'
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de l\'enregistrement: ' . $e->getMessage()
            ], 500);
        }
    }
}
