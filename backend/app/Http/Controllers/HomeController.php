<?php

namespace App\Http\Controllers;

use App\Models\Currencie;
use App\Models\Facture;
use App\Models\FactureDetail;
use App\Models\MouvementStock;
use App\Models\Produit;
use App\Models\RestaurantTable;
use App\Models\SaleDay;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class HomeController extends Controller
{
    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        // Removed auth middleware to allow API access without token
    }


    /**
     * Créer une facture pour la commande
     * @return mixed
    */
    public function saveFacture(Request $request)
    {
        try {
             $data = $request->validate([
                'ets_id' => 'required|integer',
                'facture_id' => 'nullable|exists:factures,id',
                'table_id' => 'nullable|exists:restaurant_tables,id',
                'chambre_id' => 'nullable|exists:chambres,id',
                'user_id' => 'nullable|exists:users,id',
                'remise' => 'nullable|numeric|min:0',
                'details' => 'required|array|min:1',
                'details.*.produit_id' => 'required|exists:produits,id',
                'details.*.quantite' => 'required|integer|min:1',
                'details.*.prix_unitaire' => 'required|numeric|min:0',
            ]);

$ets_id = $data['ets_id'];
            $serveur = User::find($data['user_id'] ?? null);

            if (!$serveur) {
                return response()->json([
                    'errors' => 'Utilisateur non trouvé !'
                ], 400);
            }

            $saleDay = SaleDay::whereNull('end_time')
                ->where('ets_id', $ets_id)
                ->latest()
                ->first();

            if (!$saleDay) {
                return response()->json([
                    'errors' => 'La journée de vente n\'est pas ouverte !'
                ], 400);
            }

            $facture = DB::transaction(function () use ($data, $saleDay, $serveur, $ets_id) {
                if (!empty($data['facture_id'])) {
                    $facture = Facture::findOrFail($data['facture_id']);
                } else {
                    $facture = new Facture();
                    $facture->numero_facture = 'FAC-' . time();
                }

                $facture->user_id = $serveur->id;
                $facture->table_id = $data['table_id'] ?? null;
                $facture->chambre_id = $data['chambre_id'] ?? null;
                $facture->sale_day_id = $saleDay->id;
                $facture->remise = $data['remise'] ?? 0;
                $facture->statut = "en_attente";
                $facture->emplacement_id = $serveur->emplacement_id ?? 1;
                $facture->ets_id = $ets_id;
                $facture->date_facture = Carbon::now('Africa/Kinshasa');

                // Calcul total HT
                $total_ht = collect($data['details'])->sum(function ($detail) {
                    return (int)$detail['quantite'] * (float)$detail['prix_unitaire'];
                });

                $details = $data["details"];
                $tva = 0;
                foreach($details as $d){
                    $product = Produit::find((int)$d["produit_id"]);
                    if($product->tva){
                        $tva += ((float)$d["prix_unitaire"] * (int)$d["quantite"]) * 0.16;
                    }
                }
                $facture->total_ht = $total_ht;
                $facture->tva = $tva;
                $facture->total_ttc = $total_ht - $facture->remise + $tva;
                $facture->save();

                // ✅ Créer ou mettre à jour chaque détail en fonction de facture_id + produit_id
                $produitIds = [];
                foreach ($data['details'] as $detail) {
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

                // Supprimer les détails de la facture non présents dans la requête
                FactureDetail::where('facture_id', $facture->id)
                    ->whereNotIn('produit_id', $produitIds)
                    ->delete();

                if (!empty($data['table_id'])) {
                    RestaurantTable::where('id', $data['table_id'])->update([
                        'statut' => 'occupée',
                    ]);
                }
                return $facture;
            });

            $facture->load('details.produit');

            return response()->json([
                'status' => 'success',
                'result' => $facture,
                'message' => !empty($data['facture_id'])
                    ? 'Facture modifiée avec succès !'
                    : 'Facture créée avec succès !'
            ]);
        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json(['errors' => $e->validator->errors()->all()], 422);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()], 500);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
    }

    public function linkFactures(Request $request)
    {
        try {

            $data = $request->validate([
                'factures' => 'required|array|min:2',
                'factures.*' => 'required|exists:factures,id',
                'user_id' => 'nullable|exists:users,id'
            ]);

            $user = Auth::user();
            $serveur = User::find($data['user_id'] ?? null) ?? $user;

            $saleDay = SaleDay::whereNull('end_time')
                ->where('ets_id', $user->ets_id)
                ->latest()
                ->first();

            $facture = DB::transaction(function () use ($data, $serveur, $saleDay) {

                // 🎯 Choisir une facture principale aléatoirement
                $facturePrincipaleId = collect($data['factures'])->random();
                $facturePrincipale = Facture::with('details')->findOrFail($facturePrincipaleId);

                // Liste des autres factures à fusionner
                $facturesAFusionner = collect($data['factures'])
                    ->filter(fn($id) => $id != $facturePrincipaleId)
                    ->values()
                    ->all();

                $factures = Facture::with('details')->whereIn('id', $facturesAFusionner)->get();

                $total_ht = $facturePrincipale->total_ht;
                $tva = $facturePrincipale->tva;

                foreach ($factures as $f) {
                    foreach ($f->details as $d) {

                        $pid = $d->produit_id;
                        $quantiteFusion = $d->quantite;
                        $prixUnit = $d->prix_unitaire;
                        $lineTotal = $quantiteFusion * $prixUnit;

                        // Vérifier si le produit existe déjà dans la facture principale
                        $existingDetail = FactureDetail::where('facture_id', $facturePrincipaleId)
                            ->where('produit_id', $pid)
                            ->first();

                        if ($existingDetail) {
                            // 🔁 Incrémenter la quantité au lieu de créer une nouvelle ligne
                            $existingDetail->update([
                                'quantite' => $existingDetail->quantite + $quantiteFusion,
                                'total_ligne' => ($existingDetail->quantite + $quantiteFusion) * $prixUnit,
                            ]);
                        } else {
                            // ➕ Ajouter un nouveau produit
                            FactureDetail::create([
                                'facture_id' => $facturePrincipaleId,
                                'produit_id' => $pid,
                                'quantite' => $quantiteFusion,
                                'prix_unitaire' => $prixUnit,
                                'total_ligne' => $lineTotal,
                            ]);
                        }

                        // Recalcul total HT + TVA
                        $total_ht += $lineTotal;

                        $product = Produit::find($pid);
                        if ($product && $product->tva) {
                            $tva += ($lineTotal * 0.16);
                        }
                    }
                }
                // Mise à jour des totaux
                $facturePrincipale->update([
                    'total_ht' => $total_ht,
                    'tva' => $tva,
                    'total_ttc' => $total_ht + $tva,
                ]);

                // 🗑 Supprimer les anciennes factures
                FactureDetail::whereIn('facture_id', $facturesAFusionner)->delete();
                Facture::whereIn('id', $facturesAFusionner)->delete();

                return $facturePrincipale;
            });

            $facture->load("details.produit");

            return response()->json([
                'status' => 'success',
                'result' => $facture,
                'message' => "Factures fusionnées avec succès !"
            ]);

        } catch (\Exception $e) {
            return response()->json(['errors' => $e->getMessage()], 500);
        }
    }




    /**
     * Affiche toutes les factures et commande
     * @return mixed
    */
    public function getAllFacturesCmds(Request $request)
    {
        $user = Auth::user();
        $isServeur = $user->role === "serveur";
        $status = $request->query("status") ?? null;

        $req = Facture::with([
            "details.produit.categorie",
            "table.emplacement",
            "chambre.emplacement",
            "payments",
            "saleDay",
            "user"
        ])
        ->when($status, function ($query) use ($status) {
            $query->where("statut", "en_attente");
        })
        ->when($isServeur, function ($query) use ($user) {
            $query->where("user_id", $user->id);
        })->where("ets_id", $user->ets_id);

        if($user->role !== "admin" && $user->emplacement_id){
            $req->where("emplacement_id", $user->emplacement_id);
        }
        $factures = $req->orderByDesc("id")->get();

        return response()->json([
            "status" => "success",
            "factures" => $factures
        ]);
    }


    /**
     * Voir toutes les ventes d'une journée ouvrable
     * @return mixed
    */
    /* public function getAllSells(Request $request)
    {
        $dateRange = $request->query("dateRange");
        $serveurId = $request->query("serveur");
        $saleDay = SaleDay::whereNull("end_time")->latest()->first();

        $req = MouvementStock::with("produit")
            ->selectRaw("produit_id, SUM(quantite) as total_vendu")
            ->where("type_mouvement", "vente");

        $req->when($dateRange, function ($q) use ($dateRange) {
            [$start, $end] = explode(";", $dateRange);
            $q->whereBetween("date_mouvement", [
                $start . " 00:00:00",
                $end . " 23:59:59"
            ]);
        });

        $req->when($serveurId, function ($q) use ($serveurId) {
            $q->where("user_id", $serveurId);
        });

        $req->when(!$dateRange, function ($q) use ($saleDay) {
            $q->where("sale_day_id", $saleDay->id);
        });

        $sells = $req->groupBy("produit_id")->get();

        return response()->json([
            "status" => "success",
            "ventes" => $sells
        ]);
    } */
    public function getAllSells(Request $request)
    {
        $dateRange = $request->query("dateRange");
        $serveurId = $request->query("serveur");
        $user = Auth::user();
        $saleDay = SaleDay::whereNull("end_time")->where("ets_id", $user->ets_id)->latest()->first();

        $req = MouvementStock::with(["produit", "facture.user"])
            ->selectRaw("produit_id, SUM(quantite) as total_vendu")
            ->where("type_mouvement", "vente");

        $req->when($dateRange, function ($q) use ($dateRange) {
            [$start, $end] = explode(";", $dateRange);
            $q->whereBetween("date_mouvement", [
                $start . " 00:00:00",
                $end . " 23:59:59"
            ]);
        });

        $req->when(!$dateRange, function ($q) use ($saleDay) {
            $q->where("sale_day_id", $saleDay->id);
        });

        $req->where("ets_id", $user->ets_id);

        // Restriction par emplacement pour non-admin
        if($user->role !== 'admin' && $user->emplacement_id){
            $req->where("emplacement_id", $user->emplacement_id);
        }

        $sells = $req->groupBy("produit_id")->get();

        $sells->map(function ($item) use ($dateRange, $saleDay, $serveurId, $user) {

            $query = MouvementStock::with("facture.user")
                ->selectRaw("numdoc, SUM(quantite) as quantite")
                ->where("type_mouvement", "vente")
                ->where("produit_id", $item->produit_id)
                ->whereNotNull("numdoc"); // s'assurer que c'est lié à une facture

            // Appliquer les mêmes filtres de date
            $query->when($dateRange, function ($q) use ($dateRange) {
                [$start, $end] = explode(";", $dateRange);
                $q->whereBetween("date_mouvement", [
                    $start . " 00:00:00",
                    $end . " 23:59:59"
                ]);
            });

            $query->when(!$dateRange, function ($q) use ($saleDay) {
                $q->where("sale_day_id", $saleDay->id);
            });

            if($user->role !== 'admin' && $user->emplacement_id){
                $query->where("emplacement_id", $user->emplacement_id);
            }

            // Filtrer par serveur si demandé
            if($serveurId){
                $query->whereHas("facture", function ($q) use ($serveurId) {
                    $q->where("user_id", $serveurId);
                });
            }

            $users = $query->groupBy("numdoc")->get();

            // Calculer montant par utilisateur/facture
            $item->byUsers = $users->map(function ($u) use ($item) {
                return [
                    "facture_id" => $u->numdoc,
                    "user_id" => $u->facture->user->id ?? null,
                    "nom" => $u->facture->user->name ?? "Inconnu",
                    "quantite" => $u->quantite,
                    "montant" => $u->quantite * $item->produit->prix_unitaire,
                ];
            });

            return $item;
        });

        return response()->json([
            "status" => "success",
            "ventes" => $sells
        ]);
    }



    public function dashboardCounter()
    {
        $user = Auth::user();
        $isServeur = $user->role === "serveur";
        $saleDay = SaleDay::whereNull("end_time")->where("ets_id", $user->ets_id)->latest()->first();
        $emplacementId = $user->emplacement_id ?? null;

        // Factures en attente
        $pendingInvoice = Facture::where("statut", "en_attente")
            ->when($isServeur, function ($query) use ($user) {
                $query->where("user_id", $user->id);
            })
            ->when($saleDay, function ($query) use ($saleDay) {
                $query->where("sale_day_id", $saleDay->id);
            })
            ->when($emplacementId, function ($query) use ($user) {
                $query->where("emplacement_id", $user->emplacement_id);
            })
            ->where("ets_id", $user->ets_id)
            ->count();

        // Toutes les factures du jour
        $allFactureOfDay = Facture::when($isServeur, function ($query) use ($user) {
                $query->where("user_id", $user->id);
            })
            ->when($saleDay, function ($query) use ($saleDay) {
                $query->where("sale_day_id", $saleDay->id);
            })
            ->when($emplacementId, function ($query) use ($user) {
                $query->where("emplacement_id", $user->emplacement_id);
            })
            ->where("ets_id", $user->ets_id)
            ->count();
        $cancelledFactures = Facture::when($isServeur, function ($query) use ($user) {
                $query->where("user_id", $user->id);
            })->when($saleDay, function ($query) use ($saleDay) {
                $query->where("sale_day_id", $saleDay->id);
            })->where("statut", "annulée")
            ->when($emplacementId, function ($query) use ($user) {
                $query->where("emplacement_id", $user->emplacement_id);
            })
            ->where("ets_id", $user->ets_id)
            ->count();
        $daySells = MouvementStock::when($isServeur, function ($query) use ($user) {
                $query->where("user_id", $user->id);
            })->when($saleDay, function ($query) use ($saleDay) {
                $query->where("sale_day_id", $saleDay->id);
            })->where("type_mouvement", "vente")
            ->when($emplacementId, function ($query) use ($user) {
                $query->where("emplacement_id", $user->emplacement_id);
            })
            ->where("ets_id", $user->ets_id)
            ->count();

        // Utilisateurs connectés
        $connectedUsers = User::whereHas('lastLog', function ($query) {
                $query->where('status', 'online');
            })
            ->when($emplacementId, function ($query) use ($user) {
                $query->where("emplacement_id", $user->emplacement_id);
            })
            ->where("ets_id", $user->ets_id)
            ->count();

        return response()->json([
            "status" => "success",
            "counts" => [
                "facs" => $this->padLeft($allFactureOfDay),
                "pendings" => $this->padLeft($pendingInvoice),
                "cancelled" => $this->padLeft($cancelledFactures),
                "users" => $this->padLeft($connectedUsers),
                "sells"=> $this->padLeft($daySells)
            ]
        ]);
    }


    private function padLeft($str){
        return $str;  /* str_pad((string)$str,2,  "0", STR_PAD_LEFT); */
    }


}
