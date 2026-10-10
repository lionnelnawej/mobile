<?php

namespace App\Http\Controllers;

use App\Models\Inventaire;
use App\Models\InventoryDetail;
use App\Models\MouvementStock;
use App\Models\Produit;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class InventoryController extends Controller
{

    // Pour afficher la liste des inventaires faits
    public function getInventoriesHistory()
    {
        $user = Auth::user();
        $inventories = Inventaire::with(['details.produit', 'admin', 'emplacement'])
            ->where('ets_id', $user->ets_id)
            ->orderByRaw("
                CASE 
                    WHEN status = 'pending' THEN 0 
                    ELSE 1 
                END
            ")
            ->orderBy('created_at', 'desc')
            ->paginate(10);

        return response()->json([
            'status' => 'success',
            'inventories' => $inventories,
        ]);
    }

     /**
     * Commence un inventaire physique.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function startInventory(Request $request)
    {
        try{
            $data = $request->validate([
                'emplacement_id'=>'required|int|exists:emplacements,id'
            ], ["emplacement_id"=>"emplacement de l'inventaire réquis."]);
            $inventory = Inventaire::create([
                'date_debut' => Carbon::now(tz: "Africa/Kinshasa"),
                'status' => 'pending',
                'admin_id' => Auth::id(),
                'emplacement_id' => $data["emplacement_id"],
                'ets_id' => Auth::user()->ets_id,
            ]);
            return response()->json([
                'status'=>'success',
                'result' => 'Inventaire démarré.',
                'inventory'=>$inventory
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors ]);
        }
        catch (\Illuminate\Database\QueryException $e){
            return response()->json(['errors' => $e->getMessage() ]);
        }
    }


    public function getCurrentInventory()
    {
        $inventory = Inventaire::where('admin_id', Auth::id())
            ->where('status', 'pending')
            ->latest()
            ->first();

        if ($inventory) {
            return response()->json([
                'status' => 'success',
                'inventory' => $inventory
            ]);
        }
        return response()->json([
            'status' => 'failed',
            'inventory' => null
        ]);
    }


    public function getAllProductsWithStock(Request $request)
    {
        $ets_id = Auth::user()->ets_id;
        $empId = $request->query('emp_id');

        $products = Produit::with('categorie')
            ->get()
            ->map(function ($product) use ($ets_id, $empId) {

                $mouvements = $product->stocks()->where('ets_id', $ets_id)->where("emplacement_id", $empId)->get();

                $total_entree = $mouvements->where('type_mouvement', 'entrée')->sum('quantite');
                $total_sortie = $mouvements->where('type_mouvement', 'sortie')->sum('quantite');
                $total_vente = $mouvements->where('type_mouvement', 'vente')->sum('quantite');
                $total_transfert_entree = $mouvements->where('type_mouvement', 'transfert')->where('destination', $product->emplacement_id)->sum('quantite');
                $total_transfert_sortie = $mouvements->where('type_mouvement', 'transfert')->where('source', $product->emplacement_id)->sum('quantite');
                $ajustement_plus = $mouvements->where('type_mouvement', 'ajustement')->where('quantite', '>', 0)->sum('quantite');
                $ajustement_moins = $mouvements->where('type_mouvement', 'ajustement')->where('quantite', '<', 0)->sum(function ($m) {
                    return abs($m->quantite);
                });

                // Stock final
                $stock_global = 
                    + $total_entree
                    + $total_transfert_entree
                    + $ajustement_plus
                    - $total_sortie
                    - $total_vente
                    - $total_transfert_sortie
                    - $ajustement_moins;

                $product->stock_global = $stock_global;

                return $product;
            });

        return response()->json(['products' => $products]);
    }

    /**
     * Supprimer un inventaire en cours
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function deleteInventory(Request $request)
    {
        try{
            $data = $request->validate([
                'inventory_id'=>'required|int|exists:inventaires,id'
            ]);
            $inventory = Inventaire::where("id", $data["inventory_id"])->delete();
            return response()->json([
                'status'=>'success',
                'result' => 'Inventaire annulé avec succès.',
                'inventory'=>$inventory
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors ]);
        }
        catch (\Illuminate\Database\QueryException $e){
            return response()->json(['errors' => $e->getMessage() ]);
        }
        
    }

    /**
     * Valide un inventaire avec les quantités physiques.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function validateInventory(Request $request)
    {
        try{
            $validated = $request->validate([
                'inventory_id' => 'required|exists:inventaires,id',
                'items' => 'required|array|min:1',
                'items.*.product_id' => 'required|exists:produits,id',
                'items.*.real_quantity' => 'required|integer',
                'items.*.theoretical_quantity' => 'required|integer'
            ], [
                'items'=>'vous devez sélectionner les produits.',
                'items.*.real_quantity'=>'la quantité physique doit etre renseignée.',
            ]);
    
            return DB::transaction(function () use ($validated) {
                $inventory = Inventaire::findOrFail($validated['inventory_id']);
                $inventory->update([
                    'status' => 'closed', 
                    'date_fin' => Carbon::now('Africa/Kinshasa'), 
                ]);

                foreach ($validated['items'] as $item) {

                    $product = Produit::find($item['product_id']);
                    $difference = $item['real_quantity'] - $item["theoretical_quantity"];

                    InventoryDetail::create([
                        "inventory_id"=>$inventory->id,
                        "produit_id"=>$item["product_id"],
                        "quantite_theorique"=>$item["theoretical_quantity"],
                        "quantite_physique"=>$item["real_quantity"],
                        "ecart"=>$difference
                    ]);

                    if ($difference != 0) {
                        //$product->update(['qte_init' => $item['real_quantity']]);
                        MouvementStock::create([
                            'produit_id' => $item['product_id'],
                            'quantite' => $difference,
                            'type_mouvement' => 'ajustement',
                            'user_id'=> Auth::id(),
                            'ets_id'=> Auth::user()->ets_id,
                            'emplacement_id'=> $inventory->emplacement_id,
                            'date_mouvement' => Carbon::today(),
                        ]);
                    }
                }
    
                return response()->json([
                    'status'=>'success',
                    'result' => 'Inventaire validé.',
                    'inventory'=>$inventory
                ]);
            });
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors ]);
        }
        catch (\Illuminate\Database\QueryException $e){
            return response()->json(['errors' => $e->getMessage() ]);
        }
        
    }

}
