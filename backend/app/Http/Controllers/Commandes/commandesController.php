<?php

namespace App\Http\Controllers\Commandes;

use App\Models\Facture;
use App\Models\Produit;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class commandesController extends Controller
{
    public function index(Request $request)
    {
        $ets_id = $request->query('ets_id');
        $user_id = $request->query('user_id');

        // Allow access without authentication by using user_id parameter
        if (!$ets_id && !$user_id) {
            return response()->json(['error' => 'ets_id or user_id parameter is required'], 400);
        }

        // If ets_id is provided, return all active orders for that establishment
        if ($ets_id) {
            $commandes = Facture::with('user', 'table', 'chambre')
                ->where('statut', '!=', 'payée')
                ->where('ets_id', $ets_id)
                ->orderBy('created_at', 'desc')
                ->get();

            return response()->json([
                'status' => 'success',
                'commandes' => $commandes
            ]);
        }

        // If only user_id is provided, get user info and filter accordingly
        if ($user_id) {
            $user = \App\Models\User::find($user_id);

            if (!$user) {
                return response()->json(['error' => 'User not found'], 404);
            }

            // Check user role and return appropriate data
            if ($user->hasRole('admin') || $user->hasRole('manager')) {
                $commandes = Facture::with('user', 'table', 'chambre')
                    ->where('statut', '!=', 'payée')
                    ->orderBy('created_at', 'desc')
                    ->get();
            } else if ($user->role == 'caissier') {
                $commandes = Facture::with('user', 'table', 'chambre')
                    ->where('emplacement_id', $user->emplacement_id)
                    ->where('statut', '!=', 'payée')
                    ->orderBy('created_at', 'desc')
                    ->get();
            } else {
                // For serveurs, return only their orders
                $commandes = Facture::with('user', 'table', 'chambre')
                    ->where('user_id', $user_id)
                    ->where('statut', '!=', 'payée')
                    ->orderBy('created_at', 'desc')
                    ->get();
            }

            return response()->json([
                'status' => 'success',
                'commandes' => $commandes
            ]);
        }

        return response()->json(['error' => 'Invalid parameters'], 400);
    }

    /**
     * Update order details (add/remove items)
     */
    public function update(Request $request, $id)
    {
        $data = $request->validate([
            'ets_id' => 'required|integer',
            'details' => 'required|array|min:1',
            'details.*.produit_id' => 'required|exists:produits,id',
            'details.*.quantite' => 'required|integer',
            'details.*.prix_unitaire' => 'required|numeric|min:0',
            'remise' => 'nullable|numeric|min:0',
        ]);

        $ets_id = $data['ets_id'];
        $facture = Facture::find($id);

        if (!$facture) {
            return response()->json(['error' => 'Commande non trouvée'], 404);
        }

        if ($facture->statut === 'payée') {
            return response()->json(['error' => 'Cette commande est déjà payée'], 400);
        }

        // Update remise
        if (isset($data['remise'])) {
            $facture->remise = $data['remise'];
        }

        // Recalculate totals
        $total_ht = collect($data['details'])->sum(function ($detail) {
            return (int)$detail['quantite'] * (float)$detail['prix_unitaire'];
        });

        $details = $data["details"];
        $tva = 0;
        foreach($details as $d){
            $product = Produit::find((int)$d["produit_id"]);
            if($product && $product->tva){
                $tva += ((float)$d["prix_unitaire"] * (int)$d["quantite"]) * 0.16;
            }
        }

        $facture->total_ht = $total_ht;
        $facture->tva = $tva;
        $facture->total_ttc = $total_ht - $facture->remise + $tva;
        $facture->save();

        // Update or create details
        $produitIds = [];
        foreach ($data['details'] as $detail) {
            if ($detail['quantite'] > 0) {
                $detailRecord = FactureDetail::updateOrCreate(
                    [
                        'facture_id' => $facture->id,
                        'produit_id' => $detail['produit_id'],
                    ],
                    [
                        'quantite' => $detail['quantite'],
                        'prix_unitaire' => $detail['prix_unitaire'],
                        'total_ligne' => $detail['quantite'] * $detail['prix_unitaire'],
                    ]
                );
                $produitIds[] = $detailRecord->produit_id;
            }
        }

        // Remove details not in request (if quantite is 0)
        FactureDetail::where('facture_id', $facture->id)
            ->whereNotIn('produit_id', $produitIds)
            ->delete();

        // Reload the facture with details
        $facture = Facture::with('details', 'user', 'table', 'chambre')->find($id);

        return response()->json([
            'status' => 'success',
            'message' => 'Commande mise à jour avec succès',
            'facture' => $facture
        ]);
    }

    public function servir($id){
         $user = auth()->user();

         $facture=Facture::where("id",$id)->first();

         if($facture->statut !="payée"){
            return redirect()->back()->with("error","La facture n'est pas encore, la table ne peutpas etre servie");
         }
          if($facture->statut_service =="servie"){
            return redirect()->back()->with("error","Cette table a été déjà servie");
         }

         if($user->role=='admin'){
            $facture->statut_service="servie";
            $facture->save();
            return redirect()->back()->with("success","Une table a été servie avec succès");
         }
          if($user->role=='caissier'){
            $facture->statut_service="servie";
            $facture->save();
            return redirect()->back()->witht("success","Une table a été servie avec succès");
         }

    }
    public function edit($id){
         $user = auth()->user();
    if($user->role !='caissier' && $user->role !='admin'){
        return redirect()->back()->with("error","Vous n'avez pas la permission de modifier cette commande");
    }

    if($user->role=="admin" || $user->role=="manager"){
        $facture=Facture::where("id",$id)->first();
    }else{
        $facture=Facture::where("id",$id)->where("emplacement_id",$user->emplacement_id)->first();
    }

    if(!$facture){
        return redirect()->back()->with("error","Facture non trouvée");
    }

    if($facture->statut =="payée"){
        return redirect()->back()->with("error","Cette commande ne peut pas être modifiée");
    }

    if($facture->statut_service =="servie"){
        return redirect()->back()->with("error","Cette table a été déjà servie");
    }

    $detailsFactures = $facture->details;

    // Récupérer tous les produits
    $produits = Produit::with('categorie')
        ->where('ets_id', $user->ets_id)
        ->get();

    return view('commandes.edit', compact('facture', 'detailsFactures', 'produits'));

    }
}
