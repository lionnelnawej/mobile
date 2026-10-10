<?php

namespace App\Http\Controllers;

use Exception;
use App\Models\Facture;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Auth;
use App\Models\FactureDetail;

class factureFactureController extends Controller
{
    public function delete(Request $request)
    {
        // Debug: voir ce qui est reçu
        \Log::info('Données reçues pour suppression:', $request->all());
        
        $request->validate([
            'id' => 'required|exists:factures,id'
        ]);

        try {
            DB::beginTransaction();

            // Récupérer l'ID depuis la requête
            $factureId = $request->id;
            $facture = Facture::with(['details', 'payments'])->findOrFail($factureId);

            // Vérifier que la facture est en attente
            if ($facture->statut !== 'en_attente') {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Impossible de supprimer une facture déjà payée'
                ], 422);
            }

            // Vérifier s'il y a des paiements associés
            if ($facture->paiements && $facture->paiements->count() > 0) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Impossible de supprimer une facture avec des paiements'
                ], 422);
            }

            // Supprimer les détails de la facture d'abord (si existent)
            if ($facture->details) {
                $facture->details()->delete();
            }

            // Supprimer la facture
            $facture->delete();

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Facture supprimée avec succès'
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500);
        }
    }

    public function fusionner(Request $request)
    {
        Log::info('=== DÉBUT FUSION FACTURES ===');
        Log::info('Données reçues:', $request->all());

        // Validation
        $request->validate([
            'facture_ids' => 'required|array|min:2',
            'facture_ids.*' => 'exists:factures,id',
            'table_id' => 'required'
        ]);

        try {
            DB::beginTransaction();

            $factureIds = $request->facture_ids;
            $tableId = $request->table_id;

            Log::info('IDs factures à fusionner:', $factureIds);
            Log::info('Table ID:', ['table_id' => $tableId]);

            // Récupérer les factures avec leurs détails
            $factures = Facture::with(['details.produit'])->whereIn('id', $factureIds)->get();

            Log::info('Factures trouvées:', ['count' => $factures->count()]);
            $emplacement_id = "";
            // Vérifications
            foreach ($factures as $facture) {
                Log::info('Vérification facture:', [
                    'id' => $facture->id,
                    'table_id' => $facture->table_id,
                    'statut' => $facture->statut,
                    'statut_service' => $facture->statut_service
                ]);

                if ($facture->table_id != $tableId) {
                    Log::warning('Erreur: Facture sur table différente', ['facture_id' => $facture->id]);
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Toutes les factures doivent être sur la même table'
                    ], 422);
                }

                if ($facture->statut !== 'en_attente') {
                    Log::warning('Erreur: Facture non en attente', ['facture_id' => $facture->id, 'statut' => $facture->statut]);
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Seules les factures en attente peuvent être fusionnées'
                    ], 422);
                }

                if ($facture->statut_service === 'servie') {
                    Log::warning('Erreur: Facture déjà servie', ['facture_id' => $facture->id]);
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Impossible de fusionner une facture déjà servie'
                    ], 422);
                }
                $emplacement_id=$facture->emplacement_id;
            }
            
            // Créer une nouvelle facture fusionnée
            $nouvelleFacture = new Facture();
            $nouvelleFacture->numero_facture = 'FAC-' . time();
            $nouvelleFacture->table_id = $tableId;
            $nouvelleFacture->user_id = auth()->id();
            $nouvelleFacture->date_facture = now();
            $nouvelleFacture->statut = 'en_attente';
            $nouvelleFacture->statut_service = 'en_attente';
            $nouvelleFacture->sale_day_id = $factures->first()->sale_day_id;
            $nouvelleFacture->remise = 0;
            $nouvelleFacture->ets_id=Auth::user()->ets_id;
            $nouvelleFacture->emplacement_id= $emplacement_id;
            $nouvelleFacture->total_ht = 0;
            $nouvelleFacture->total_ttc = 0;
            
            // Sauvegarder la facture pour avoir un ID
            $nouvelleFacture->save();
            
            Log::info('Nouvelle facture créée:', [
                'id' => $nouvelleFacture->id,
                'numero' => $nouvelleFacture->numero_facture
            ]);

            $totalHT = 0;
            $totalTTC = 0;

            // Tableau pour regrouper les produits similaires
            $produitsRegroupes = [];

            // Parcourir toutes les factures et leurs détails
            foreach ($factures as $facture) {
                Log::info('Traitement facture:', [
                    'id' => $facture->id, 
                    'details_count' => $facture->details->count()
                ]);
                
                foreach ($facture->details as $detail) {
                    $produitId = $detail->produit_id;
                    $prixUnitaire = $detail->prix_unitaire;
                    
                    // Regrouper par produit et prix unitaire
                    $key = $produitId . '_' . $prixUnitaire;
                    
                    if (isset($produitsRegroupes[$key])) {
                        // Produit déjà existant, on additionne les quantités
                        $produitsRegroupes[$key]['quantite'] += $detail->quantite;
                        $produitsRegroupes[$key]['total_ligne'] += $detail->total_ligne;
                    } else {
                        // Nouveau produit
                        $produitsRegroupes[$key] = [
                            'produit_id' => $produitId,
                            'quantite' => $detail->quantite,
                            'prix_unitaire' => $prixUnitaire,
                            'total_ligne' => $detail->total_ligne
                        ];
                    }
                    
                    $totalHT += $detail->total_ligne;
                    
                    Log::info('Détail traité:', [
                        'produit_id' => $produitId,
                        'quantite' => $detail->quantite,
                        'prix_unitaire' => $prixUnitaire,
                        'total_ligne' => $detail->total_ligne
                    ]);
                }
            }

            Log::info('Produits regroupés:', ['count' => count($produitsRegroupes)]);
            Log::info('Total HT calculé:', ['total_ht' => $totalHT]);

            // Créer les nouveaux détails regroupés
            foreach ($produitsRegroupes as $key => $produitRegroupe) {
                $nouveauDetail = new FactureDetail();
                $nouveauDetail->facture_id = $nouvelleFacture->id;
                $nouveauDetail->produit_id = $produitRegroupe['produit_id'];
                $nouveauDetail->quantite = $produitRegroupe['quantite'];
                $nouveauDetail->prix_unitaire = $produitRegroupe['prix_unitaire'];
                $nouveauDetail->total_ligne = $produitRegroupe['total_ligne'];
                $nouveauDetail->save();

                Log::info('Nouveau détail créé:', [
                    'produit_id' => $produitRegroupe['produit_id'],
                    'quantite' => $produitRegroupe['quantite'],
                    'prix_unitaire' => $produitRegroupe['prix_unitaire'],
                    'total_ligne' => $produitRegroupe['total_ligne']
                ]);
            }

            // Calculer les totaux
            $totalTTC = $totalHT;

            // Mettre à jour les totaux de la facture fusionnée
            $nouvelleFacture->total_ht = $totalHT;
            $nouvelleFacture->total_ttc = $totalTTC;
            $nouvelleFacture->save();

            Log::info('Totaux facture fusionnée:', [
                'total_ht' => $totalHT,
                'total_ttc' => $totalTTC
            ]);

            // Marquer les anciennes factures comme fusionnées (suppression douce)
            foreach ($factureIds as $factureId) {
                $facture = Facture::find($factureId);
                
                // Option 1: Supprimer définitivement
                $facture->delete();
                
                // Option 2: Marquer comme fusionné (si vous avez le champ)
                // $facture->statut = 'fusionnée';
                // $facture->save();

                Log::info('Ancienne facture traitée:', [
                    'ancienne_facture_id' => $factureId,
                    'action' => 'supprimée'
                ]);
            }

            DB::commit();

            Log::info('=== FUSION TERMINÉE AVEC SUCCÈS ===');

            return response()->json([
                'status' => 'success',
                'message' => $factures->count() . ' factures fusionnées avec succès',
                'nouvelle_facture_id' => $nouvelleFacture->id,
                'numero_facture' => $nouvelleFacture->numero_facture,
                'total_ttc' => $nouvelleFacture->total_ttc
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            
            Log::error('ERREUR FUSION FACTURES: ' . $e->getMessage());
            Log::error('Stack trace: ' . $e->getTraceAsString());
            
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de la fusion: ' . $e->getMessage()
            ], 500);
        }
    }

    public function supprimer(Request $request)
    {
        Log::info('=== DÉBUT SUPPRESSION FACTURE ===');
        Log::info('Données reçues:', $request->all());
        
        $request->validate([
            'id' => 'required|exists:factures,id'
        ]);

        try {
            DB::beginTransaction();

            $facture = Facture::with(['details', 'payments'])->findOrFail($request->id);

            Log::info('Facture trouvée:', [
                'id' => $facture->id,
                'statut' => $facture->statut,
                'payments_count' => $facture->payments ? $facture->payments->count() : 0
            ]);

            // Vérifications
            if ($facture->statut !== 'en_attente') {
                Log::warning('Erreur: Facture non en attente', ['statut' => $facture->statut]);
                return response()->json([
                    'status' => 'error',
                    'message' => 'Impossible de supprimer une facture déjà payée'
                ], 422);
            }

            if ($facture->payments && $facture->payments->count() > 0) {
                Log::warning('Erreur: Facture avec paiements', ['payments_count' => $facture->payments->count()]);
                return response()->json([
                    'status' => 'error',
                    'message' => 'Impossible de supprimer une facture avec des paiements'
                ], 422);
            }

            // Supprimer les détails
            if ($facture->details) {
                $detailsCount = $facture->details->count();
                $facture->details()->delete();
                Log::info('Détails supprimés:', ['count' => $detailsCount]);
            }

            // Supprimer la facture
            $facture->delete();

            DB::commit();

            Log::info('=== SUPPRESSION RÉUSSIE ===');

            return response()->json([
                'status' => 'success',
                'message' => 'Facture supprimée avec succès'
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            
            Log::error('ERREUR SUPPRESSION FACTURE: ' . $e->getMessage());
            Log::error('Stack trace: ' . $e->getTraceAsString());
            
            return response()->json([
                'status' => 'error',
                'message' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500);
        }
    }
    
}
