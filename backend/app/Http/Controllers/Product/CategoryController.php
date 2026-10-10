<?php

namespace App\Http\Controllers\Product;

use Exception;
use App\Models\Categorie;
use Illuminate\Http\Request;
use App\Models\FactureDetail;
use App\Models\MouvementStock;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;

class CategoryController extends Controller
{
    public function supprimerAvecProduits(Request $request)
    {
        $request->validate([
            'id' => 'required|exists:categories,id'
        ]);

        try {
            DB::beginTransaction();

            $categorie = Categorie::with(['produits'])->findOrFail($request->id);

            $produitsCount = $categorie->produits->count();
            $produitsSupprimes = 0;
            $produitsConserves = 0;

            // Parcourir tous les produits de la catégorie
            foreach ($categorie->produits as $produit) {
                
                // Vérifier si le produit est utilisé dans des factures
                $utilisationFactures = FactureDetail::where('produit_id', $produit->id)->exists();
                
                if (!$utilisationFactures) {
                    // Le produit n'est pas utilisé dans des factures, on peut le supprimer
                    
                    // 1. Supprimer les mouvements de stock associés
                    MouvementStock::where('produit_id', $produit->id)->delete();
                    
                    // 2. Supprimer les inventaires associés (si la relation existe)
                    if (method_exists($produit, 'inventaires')) {
                        $produit->inventaires()->delete();
                    }
                    
                    // 3. Supprimer le produit
                    $produit->delete();
                    $produitsSupprimes++;
                    
                } else {
                    // Le produit est utilisé dans des factures, on le conserve
                    // Mais on le décategorise (on met categorie_id à null)
                    $produit->categorie_id = null;
                    $produit->save();
                    $produitsConserves++;
                }
            }

            // Supprimer la catégorie
            $categorie->delete();

            DB::commit();

            // Message de confirmation détaillé
            $message = "Catégorie supprimée avec succès. ";
            
            if ($produitsSupprimes > 0) {
                $message .= "{$produitsSupprimes} produit(s) supprimé(s). ";
            }
            
            if ($produitsConserves > 0) {
                $message .= "{$produitsConserves} produit(s) conservé(s) (utilisés dans des factures).";
            }

            return response()->json([
                'status' => 'success',
                'message' => $message,
                'stats' => [
                    'produits_supprimes' => $produitsSupprimes,
                    'produits_conserves' => $produitsConserves,
                    'total_produits' => $produitsCount
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Version alternative : Supprimer seulement si aucun produit n'est utilisé dans des factures
     */
    public function supprimerSiSafe(Request $request)
    {
        $request->validate([
            'id' => 'required|exists:categories,id'
        ]);

        try {
            DB::beginTransaction();

            $categorie = Categorie::with(['produits'])->findOrFail($request->id);

            $produitsAvecFactures = 0;

            // Vérifier si des produits sont utilisés dans des factures
            foreach ($categorie->produits as $produit) {
                $utilisationFactures = FactureDetail::where('produit_id', $produit->id)->exists();
                if ($utilisationFactures) {
                    $produitsAvecFactures++;
                }
            }

            // Si des produits sont utilisés dans des factures, on bloque la suppression
            if ($produitsAvecFactures > 0) {
                return response()->json([
                    'status' => 'error',
                    'message' => "Impossible de supprimer cette catégorie. {$produitsAvecFactures} produit(s) sont utilisés dans des factures."
                ], 422);
            }

            // Tous les produits peuvent être supprimés
            foreach ($categorie->produits as $produit) {
                // Supprimer les mouvements de stock
                MouvementStock::where('produit_id', $produit->id)->delete();
                
                // Supprimer les inventaires
                if (method_exists($produit, 'inventaires')) {
                    $produit->inventaires()->delete();
                }
                
                // Supprimer le produit
                $produit->delete();
            }

            // Supprimer la catégorie
            $categorie->delete();

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => "Catégorie et tous ses produits supprimés avec succès"
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500);
        }
    }
}
