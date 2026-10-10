<?php

namespace App\Http\Controllers;

use App\Models\AccessAllow;
use App\Models\CaisseReport;
use App\Models\Chambre;
use App\Models\Client;
use App\Models\Currencie;
use App\Models\Emplacement;
use App\Models\Facture;
use App\Models\MouvementStock;
use App\Models\Payments;
use App\Models\Reservation;
use App\Models\RestaurantTable;
use App\Models\SaleDay;
use App\Models\User;
use App\Models\UserLog;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Spatie\Permission\Models\Permission;
use Barryvdh\DomPDF\Facade\Pdf;

class AdminController extends Controller
{
    /**
     * Fonction permettant de commencer une journée de ventes
     * @param Request $request
     * @return
    */
    public function startDay(Request $request){
        try{
            $data = $request->validate([
                "currencie_value"=>"required|numeric"
            ]);
            $user = isset($request->user_id) ? User::find((int)$request->user_id) : Auth::user();

            $currencie = Currencie::updateOrCreate(
                [
                    "currencie_date"=>Carbon::now()->toDateString(),
                    "ets_id"=>$user->ets_id
                ],
            [
                "currencie_date"=>Carbon::now()->toDateString(),
                "currencie_value"=>$data["currencie_value"],
                "ets_id"=>$user->ets_id
            ]);

            $saleDay = SaleDay::create(
                [
                "sale_date"=>Carbon::now(tz: "Africa/Kinshasa")->toDateString(),
                "start_time"=>Carbon::now()->setTimezone("Africa/Kinshasa"),
                "ets_id"=>$user->ets_id,
                "end_time"=>null
            ]);
            $accessAllow = AccessAllow::where("ets_id", $user->ets_id)->latest()->first();
            $accessAllow->update([
                "allowed"=>true
            ]);

            return response()->json([
                "status"=>"success",
                "result"=>[
                    "saleDay"=>$saleDay,
                    "currencie"=>$currencie,
                    "access"=>$accessAllow
                ]
            ]);

        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }
    }

    public function closeDayReport(Request $request)
    {
        try {
            $data = $request->validate([
                "serveur_id"=>"required|int|exists:users,id",
                "total_especes"=>"required|numeric",
                "tickets_serveur"=>"required|int",
                "tickets_emis"=>"required|int",
                "valeur_theorique"=>"required|numeric"
            ]);
            $user = Auth::user();
            $taux = Currencie::where('ets_id', Auth::user()->ets_id)->latest('id')->value('currencie_value') ?? 0;
            $saleDay = SaleDay::where("ets_id", $user->ets_id)->whereNull("end_time")->latest()->first();
            $data["caissier_id"] = $user->id;
            $data["sale_day_id"] = $saleDay->id;
            $data["taux"] = (double) $taux;
            $data["rapport_date"] = Carbon::now(tz:"Africa/Kinshasa")->toDateString();
            $result = CaisseReport::create($data);
            return response()->json([
                "status" => "success",
                "message" => "La journée du serveur clôturée avec succès.",
                "result" => $result
            ]);
        }catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
    }

    public function closeDay()
    {
        try {
            $user = Auth::user();
            // 1. Vérifier qu'il y a une journée ouverte
            $saleDay = SaleDay::whereNull("end_time")
                ->where("ets_id", $user->ets_id)
                ->latest("id")
                ->first();

            if (!$saleDay) {
                return response()->json([
                    "errors" => "Aucune journée ouverte à clôturer."
                ]);
            }

            // 2. Récupérer tous les serveurs ayant fait des factures dans cette journée
            $serveursAvecFactures = Facture::where("sale_day_id", $saleDay->id)
                ->pluck("user_id")
                ->unique();

            // 3. Récupérer tous les serveurs ayant déjà un rapport de caisse
            $serveursAvecRapport = CaisseReport::where("sale_day_id", $saleDay->id)
                ->pluck("serveur_id")
                ->unique();

            // 4. Identifier les serveurs qui n'ont pas encore de rapport
            $serveursManquants = $serveursAvecFactures->diff($serveursAvecRapport);

            if ($serveursManquants->isNotEmpty()) {
                // Charger les infos des serveurs manquants
                $serveursInfos = User::with("emplacement")->whereIn("id", $serveursManquants)->get();
                return response()->json([
                    "status" => "failed",
                    "message" => "Impossible de clôturer, serveurs connectés !",
                    "serveurs" => $serveursInfos
                ]);
            }
            // 5. Tout est OK → clôturer la journée
            $saleDay->update([
                "end_time" => Carbon::now()->setTimezone("Africa/Kinshasa")
            ]);

            // 6. Mettre à jour les logs utilisateurs
            UserLog::where("sale_day_id", $saleDay->id)
                ->whereNull("logged_out_at")
                ->update([
                    "logged_out_at" => Carbon::now(),
                    "status" => "offline"
                ]);
            // 7. Bloquer l'accès
            $accessAllow = AccessAllow::where("ets_id", $user->ets_id)->latest()->first();
            if ($accessAllow) {
                $accessAllow->update(["allowed" => false]);
            }
            return response()->json([
                "status" => "success",
                "message" => "La journée a été clôturée avec succès.",
                "saleDay" => $saleDay,
                "report_url" => "caisse.day.report/".$saleDay->id,
            ]);

        }catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }
    }


    public function generatePDF($sale_day_id)
    {
        $saleDay = SaleDay::findOrFail($sale_day_id);
        // Groupement des rapports par caissier
        $groupedReports = CaisseReport::with(['caissier', 'serveur'])
            ->where('sale_day_id', $sale_day_id)
            ->get()
            ->groupBy('caissier_id');

        $pdf = Pdf::loadView('pdf.caisse_day_report', [
            'saleDay' => $saleDay,
            'groupedReports' => $groupedReports,
        ])->setPaper('a4', 'portrait');

        $filename = 'Rapport_Caisse_' . $saleDay->sale_date . '.pdf';
        return $pdf->download($filename);
    }


    //GET ALL USERS
    public function getAllUsersWithLatestLog(Request $request){
        $role = $request->query("role") ?? null;
        $user = Auth::user();
        $query = User::with(["lastLog", "emplacement","permissions", "roles.permissions"])
                ->orderBy("name")->where("ets_id", $user->ets_id);
        if($role){
            $query->where("role", $role);
        }
        $users = $query->whereNot("status", "deleted")->get();
        return response()->json([
            "status"=>"success",
            "users"=>$users
        ]);
    }

    //Voir tous les serveurs
    public function getAllServeurs(Request $request){
        $user = Auth::user();
        $query = User::with(["lastLog", "emplacement","permissions", "roles.permissions"])
                ->orderBy("name")->where("ets_id", $user->ets_id)->where("role", "serveur");
        $users = $query->get();
        return response()->json([
            "status"=>"success",
            "users"=>$users
        ]);
    }
    //GET ALL SERVEURS SERVICES
    public function getAllServeursServices(Request $request)
    {
        $user = Auth::user();
        $saleDay = SaleDay::where("ets_id", $user->ets_id)
            ->whereNull("end_time")
            ->latest()
            ->first();

        if (!$saleDay) {
            return response()->json([
                "status" => "error",
                "message" => "Aucune journée de vente active trouvée."
            ]);
        }

        $req = Facture::with("user.lastLog")
            ->selectRaw("user_id, SUM(total_ttc) as total_encaisse, COUNT(id) as total_ticket")
            ->where("sale_day_id", $saleDay->id)
            ->whereHas("user", function ($q) {
                $q->where("role", "serveur");
            })
            ->where("statut", "payée")
            ->where("ets_id", $user->ets_id);
        // Si l'utilisateur n'est pas admin, filtrer selon l'emplacement
        if ($user->role !== "admin" && $user->emplacement_id) {
            $req->where("emplacement_id", $user->emplacement_id);
        }
        $serveurs = $req->groupBy("user_id")->get();
        // Ajout du statut du rapport
        $serveurs->transform(function ($srv) use ($saleDay, $user) {
            $rapport = CaisseReport::where("serveur_id", $srv->user_id)
                ->where("sale_day_id", $saleDay->id)
                ->where("caissier_id", $user->id)
                ->first();
            $srv->rapport_statut = $rapport ? "done" : "none";
            $srv->rapport_id = $rapport->id ?? null;
            return $srv;
        });

        return response()->json([
            "status" => "success",
            "serveurs" => $serveurs
        ]);
    }


    //GET ALL USER PERMISSION
    public function getAllPermissions(){
        $permissions = Permission::all();
        return response()->json([
            "status"=>"success",
            "permissions"=>$permissions
        ]);
    }


    //UPDATE SELECTED USER PERMISSION
    public function updateUserPermissions(Request $request)
    {
        try{
            // Validation
            $data = $request->validate([
                'user_id'=>'required|int|exists:users,id',
                'permissions' => 'required|array',
                'permissions.*' => 'exists:permissions,id'
            ]);
            $user = User::findOrFail($data["user_id"]);

            $permissionNames = Permission::whereIn('id', $data['permissions'])
                                ->pluck('name')
                                ->toArray();
            \Log::info('Permissions à synchroniser: ', $permissionNames);
            // Synchroniser les permissions
            $user->syncPermissions($permissionNames);
            return response()->json([
                'status'=>'success',
                'message' => 'Permissions mises à jour avec succès',
                'result' => $user->getAllPermissions()
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }

    }

    /**
     * Create Emplacement
     * @param Request $request
     * @return mixed
    */
    public function createEmplacement(Request $request){
        try{
            // Validation
            $data = $request->validate([
                "libelle"=>"required|string",
                "type"=>"required|string",
            ]);
            $data["ets_id"] = Auth::user()->ets_id;
            $emplacement = Emplacement::updateOrCreate([
                "id"=>$request->id ?? null
            ],$data);

            return response()->json([
                'status'=>'success',
                'message' => 'Nouveau emplacement créé avec succès !',
                'result' => $emplacement
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }
    }


    //GET ALL Emplacements with tables
    public function getAllEmplacements(Request $request){
        $ets_id = $request->query('ets_id');

        if (!$ets_id) {
            return response()->json(['error' => 'ets_id parameter is required'], 400);
        }

        $emplacements = Emplacement::with(["tables", "chambres"])
            ->where("ets_id", $ets_id)
            ->orderBy("libelle")->get();
        return response()->json([
            "status"=>"success",
            "emplacements"=>$emplacements
        ]);
    }

    /**
     * Create Table
     * @param Request $request
     * @return mixed
    */
    public function createTable(Request $request){
        try{
            // Validation
            $data = $request->validate([
                "numero"=>"required|string",
                "emplacement_id"=>"required|int|exists:emplacements,id",
                "prix"=>"nullable|numeric",
                "prix_devise"=>"nullable|string",
                "type"=>"nullable|string",
                "capacite"=>"nullable|string",
                "id"=>"nullable|int",
            ]);

            $user = Auth::user();
            if(isset($data["id"])){
                $cdts["id"] = $data["id"];
            }
            else{
                $cdts = [
                    "numero"=>$data["numero"],
                    "emplacement_id"=>$data["emplacement_id"]
                ];
            }

            $emplacement = Emplacement::find($data["emplacement_id"]);


            if($emplacement->type === 'hôtel'){
                $check = Chambre::where("numero",$data["numero"])->whereNot("id", $data["id"] ?? '')->where("ets_id", Auth::user()->ets_id)->first();
                if($check && $check->emplacement_id === $data['emplacement_id']){
                    return response()->json(["errors"=> "Numéro de la table existe déjà."]);
                }
                $result = Chambre::updateOrCreate(["numero"=>$data["numero"]],[
                    "numero"=>$data["numero"],
                    "prix"=>$data["prix"],
                    "prix_devise"=>$data["prix_devise"],
                    "type"=>$data["type"],
                    "capacite"=>$data["capacite"],
                    "emplacement_id"=>$data["emplacement_id"],
                    "ets_id"=>$user->ets_id
                ]);
            }else{
                $check = RestaurantTable::where("numero",$data["numero"])->whereNot("id", $data["id"])->where("ets_id", Auth::user()->ets_id)->first();
                if($check && $check->emplacement_id === $data['emplacement_id']){
                    return response()->json(["errors"=> "Numéro de la table existe déjà."]);
                }
                $result = RestaurantTable::updateOrCreate($cdts,[
                    "numero"=>$data["numero"],
                    "emplacement_id"=>$data["emplacement_id"],
                    "ets_id"=>$user->ets_id
                ]);
            }
            return response()->json([
                'status'=>'success',
                'message' => 'Nouvelle table créée avec succès !',
                'result' => $result,
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        } catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }
    }

    //GET ALL TABLES
    public function getAllTables(Request $request)
    {
        $placeId = $request->query("place") ?? null;
        $ets_id = $request->query("ets_id");

        if (!$ets_id) {
            return response()->json(['error' => 'ets_id parameter is required'], 400);
        }

        $query = RestaurantTable::with([
            "emplacement",
            "commandes" => function ($query) {
                $query->where("statut", "!=", "payée")
                    ->with(["details.produit"]);
            }
        ])->where("ets_id", $ets_id);

        if ($placeId) {
            $query->where("emplacement_id", $placeId);
        }
        $tables = $query->orderByDesc("id")->get();

        $query1 = Chambre::with("emplacement")->where("ets_id", $ets_id);
        if ($placeId) {
            $query1->where("emplacement_id", $placeId);
        }
        $chambres = $query1->orderByDesc("id")->get();

        return response()->json([
            "status" => "success",
            "tables" => $tables,
            "chambres"=> $chambres,
        ]);
    }

    public function getAllChambres(Request $request)
    {
        Artisan::call('reservations:update');
        $user = Auth::user();
        $chambres = Chambre::with(["emplacement", "reservations.client"])->where("emplacement_id", $user->emplacement_id)->get();

        return response()->json([
            "status" => "success",
            "chambres" => $chambres
        ]);
    }

    public function triggerTableOperation(Request $request)
    {
        $operation = $request->op;

        // 🔹 Transfert
        if ($operation === 'transfert') {
            $request->validate([
                'source_id' => 'required|integer|exists:restaurant_tables,id',
                'cible_id'  => 'required|integer|exists:restaurant_tables,id',
            ]);

            $tableSource = RestaurantTable::find($request->source_id);
            $tableCible  = RestaurantTable::find($request->cible_id);

            if ($tableSource->id === $tableCible->id) {
                return response()->json([
                    "errors" => "Impossible de transférer vers la même table."
                ]);
            }

            DB::transaction(function () use ($tableSource, $tableCible) {
                $tableSource->update(["statut" => "libre"]);
                $tableCible->update(["statut" => "occupée"]);

                // Déplacer toutes les commandes de la source vers la cible
                $tableSource->commandes()->update([
                    "table_id" => $tableCible->id
                ]);
            });

            return response()->json([
                "status" => "success",
                "result" => "Transfert effectué avec succès !"
            ]);
        }

        // 🔹 Combinaison
        if ($operation === 'combiner') {
            $request->validate([
                'table1_id' => 'required|integer|exists:restaurant_tables,id',
                'table2_id' => 'required|integer|exists:restaurant_tables,id',
            ]);

            $table1 = RestaurantTable::find($request->table1_id);
            $table2 = RestaurantTable::find($request->table2_id);

            if ($table1->id === $table2->id) {
                return response()->json([
                    "errors" => "Impossible de combiner une table avec elle-même."
                ]);
            }

            DB::transaction(function () use ($table1, $table2) {
                // Déplacer toutes les commandes de la table1 vers la table2
                $table1->commandes()->update([
                    "table_id" => $table2->id
                ]);

                // Libérer la table1
                $table1->update(["statut" => "libre"]);

                // Table2 reste occupée
                $table2->update(["statut" => "occupée"]);
            });

            return response()->json([
                "status" => "success",
                "result" => "Tables combinées avec succès !"
            ]);
        }

        return response()->json([
            "errors" => "Opération inconnue ou non supportée."
        ]);
    }

    public function libererTable(Request $request)
    {
        $table = RestaurantTable::find((int)$request->table_id);
        if($table){
            $table->update(["statut"=>"libre"]);
        }
        return response()->json([
            "status"=>"success",
            "result" => "Table liberée avec succès !"
        ]);
    }
    public function servirCommande(Request $request)
    {
        $commande = Facture::find((int)$request->id);
        if($commande){
            $commande->update(["statut_service"=>"servie"]);
        }
        return response()->json([
            "status"=>"success",
            "result" => "commande servie avec succès !"
        ]);
    }


    public function updateBedRoomStatus(Request $request)
    {
        $chambre = Chambre::find((int) $request->chambre_id);

        if (!$chambre) {
            return response()->json([
                'errors' => 'Chambre introuvable.',
            ]);
        }

        $today = Carbon::today();
        // Vérifier s’il existe des réservations futures ou en cours pour cette chambre
        $hasFutureReservations = Reservation::where('chambre_id', $chambre->id)
            ->where('statut', '!=', 'annulée')
            ->whereDate('date_fin', '>=', $today)
            ->exists();

        $newStatus = $chambre->statut;

        switch ($chambre->statut) {
            case 'occupée':
                // Si aucune réservation future → libre, sinon réservée
                $newStatus = $hasFutureReservations ? 'réservée' : 'libre';
                break;

            case 'réservée':
                // Si le client vient d’arriver → occupée, sinon libre si plus de résa
                if (!$hasFutureReservations) {
                    $newStatus = 'libre';
                } else {
                    $newStatus = 'occupée';
                }
                break;

            case 'libre':
                // Si on déclenche l’action et qu’il y a une résa future → réservée
                if ($hasFutureReservations) {
                    $newStatus = 'réservée';
                }
                break;
        }
        // Mise à jour uniquement si changement réel
        if ($newStatus !== $chambre->statut) {
            $chambre->update(['statut' => $newStatus]);
        }
        return response()->json([
            'status' => 'success',
            'result' => "Statut mis à jour : {$newStatus}",
            'message' => "Statut mis à jour : {$newStatus}",
        ]);
    }

    public function createPayment(Request $request){
        try{
            // Validation
            $data = $request->validate([
                "ets_id"=>"required|integer",
                "facture_id"=>"required|int|exists:factures,id",
                "user_id"=>"nullable|int|exists:users,id",
                "mode"=>"nullable|string",
                "mode_ref"=>"nullable|string",
            ]);

            $ets_id = $data['ets_id'];
            $user = \App\Models\User::find($data['user_id'] ?? null);

            $facture = Facture::find((int)$data["facture_id"]);

            if (!$facture) {
                return response()->json(['error' => 'Facture non trouvée'], 404);
            }

            $saleDay = SaleDay::whereNull("end_time")->where("ets_id", $ets_id)->latest()->first();

            if (!$saleDay) {
                return response()->json(['error' => 'La journée de vente n\'est pas ouverte'], 400);
            }

            $userId = $data["user_id"] ?? ($user ? $user->id : 1);

            if($facture){
                $payment = Payments::create([
                    "amount"=>$facture->total_ttc,
                    "devise"=>"CDF",
                    "mode"=>$data["mode"] ?? "cash",
                    "mode_ref"=>$data["mode_ref"] ?? null,
                    "pay_date"=>Carbon::now(tz:'Africa/Kinshasa'),
                    "emplacement_id"=>$facture->emplacement_id,
                    "facture_id"=>$facture->id,
                    "table_id"=>isset($facture->table_id) ? $facture->table_id : $facture->chambre_id ,
                    "user_id"=>$userId,
                    "sale_day_id"=>$saleDay->id,
                    "ets_id"=>$ets_id,
                ]);
                if($payment){
                    foreach($facture->details as $detail){
                        MouvementStock::create([
                            "produit_id"=>$detail->produit_id,
                            "numdoc"=>$facture->id,
                            "type_mouvement"=>"vente",
                            "quantite"=>$detail->quantite,
                            "sale_day_id"=>$saleDay->id,
                            "date_mouvement"=>Carbon::now(tz:"Africa/Kinshasa"),
                            "user_id"=>$userId,
                            "ets_id"=>$ets_id,
                            "emplacement_id"=>$facture->emplacement_id,
                        ]);
                    }
                    $facture->update(["statut"=>"payée"]);
                }
            }

            return response()->json([
                'status'=>'success',
                'message' => 'Paiement effectué avec succès !',
                'result' => $payment,
            ]);
        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json(['errors' => $e->getMessage()]);
        }
        catch (\Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException $e) {
            return response()->json(['errors' => "Action non autorisée !"]);
        }
    }


    //GLOBAL REPORT GROUPED BY USER
    public function viewGlobalReports(Request $request)
    {
        $saleDays = SaleDay::with([
            "sales" => function ($query) {
                $query->where("type_mouvement", "vente")
                    ->with([
                        "produit",
                        // Load the user as-is — do not filter out roles (serveur/cuisinier)
                        "user"
                    ]);
            },
            "factures" => function ($query) {
                $query->where("statut", "payée")->with(["details", "user"]);
            }
        ])->where("ets_id", Auth::user()->ets_id)
        ->orderByDesc("sale_date")
        ->get();

        $reports = collect();

        foreach ($saleDays as $saleDay) {
            // Grouper les rapports de caisse par l'utilisateur qui a clos (caissier/admin)
            $caisseReports = CaisseReport::with(['caissier', 'serveur'])
                ->where('sale_day_id', $saleDay->id)
                ->get()
                ->groupBy('caissier_id');

            if ($caisseReports->isEmpty()) {
                // Pas de rapports de caisse pour cette journée → afficher un résumé global (journée non clôturée)
                $reports->push([
                    'sale_day' => $saleDay,
                    'user' => (object)[
                        'id' => null,
                        'name' => 'Journée non clôturée',
                        'role' => '—'
                    ],
                    'total_factures' => $saleDay->factures->sum('total_ttc'),
                    'caisse_reports' => collect()
                ]);
            }

            foreach ($caisseReports as $caissierId => $reportsGroup) {
                $caissier = $reportsGroup->first()->caissier;
                // Sécurité : s'assurer que le caissier existe et appartient au même établissement
                if (!$caissier || ($caissier->ets_id ?? null) !== Auth::user()->ets_id) {
                    // ignorer les rapports provenant d'un autre établissement ou sans établissement
                    continue;
                }

                // Récupérer les serveurs pour lesquels ce caissier a soumis des rapports
                // et s'assurer qu'ils appartiennent au même établissement
                $serveurIds = $reportsGroup->pluck('serveur')->filter(function($s){
                    return $s && ($s->ets_id ?? null) === Auth::user()->ets_id;
                })->pluck('id')->unique()->values()->all();

                // Total encaissé = somme des factures payées de la journée pour ces serveurs
                $totalFactures = 0;
                if (!empty($serveurIds)) {
                    $totalFactures = $saleDay->factures->whereIn('user_id', $serveurIds)->sum('total_ttc');
                }

                // Optionnel: inclure les rapports de caisse pour affichage détaillé
                $reports->push([
                    'sale_day' => $saleDay,
                    'user' => $caissier,
                    'total_factures' => $totalFactures,
                    'caisse_reports' => $reportsGroup->values(),
                ]);
            }
        }

        // Add debug meta to help diagnose empty-result cases
        $saleDayIds = $saleDays->pluck('id')->values()->all();
        $totalCaisseReports = CaisseReport::whereIn('sale_day_id', $saleDayIds)
            ->where('ets_id', Auth::user()->ets_id)
            ->count();

        $meta = [
            'sale_days_count' => $saleDays->count(),
            'sale_day_ids' => $saleDayIds,
            'total_caisse_reports' => $totalCaisseReports,
        ];

        return response()->json([
            "status" => "success",
            "reports" => $reports->values(),
            "meta" => $meta,
        ]);
    }


    public function showDaySaleFacturesByCaissier(Request $request)
    {
        $caissierId = $request->query("id") ?? $request->query('user_id');
        $saleDayId = $request->query("sale_day_id");

        if (!$saleDayId) {
            return response()->json([
                "status" => "error",
                "message" => "sale_day_id is required"
            ], 400);
        }

        // Récupérer la saleDay et vérifier qu'elle appartient bien à l'établissement
        $saleDay = SaleDay::where('id', $saleDayId)->where('ets_id', Auth::user()->ets_id)->first();
        if (!$saleDay) {
            return response()->json([
                "status" => "error",
                "message" => "Sale day not found or does not belong to your establishment"
            ], 404);
        }

        // Récupérer les CaisseReport enregistrés par ce caissier pour la journée (limité à l'établissement)
        $caisseReports = CaisseReport::where('sale_day_id', $saleDayId)
            ->where('ets_id', Auth::user()->ets_id)
            ->when($caissierId, function ($q) use ($caissierId) {
                return $q->where('caissier_id', $caissierId);
            })
            ->get();

        $serveurIds = $caisseReports->pluck('serveur_id')->unique()->filter()->values()->all();

        // Récupérer les factures payées de la journée ; si aucun caissier spécifié, retourner toutes les factures de la journée
        $facturesQuery = Facture::with(["payments", "saleDay", "user"])
            ->where('sale_day_id', $saleDayId)
            ->where('statut', 'payée');

        if (!empty($serveurIds)) {
            $facturesQuery->whereIn('user_id', $serveurIds);
        }

        $factures = $facturesQuery->orderByDesc('id')->get();

        // Fournir des informations de debug utiles pour diagnostiquer les cas vides
        $meta = [
            'caisse_reports_count' => $caisseReports->count(),
            'serveur_ids' => $serveurIds,
            'factures_found' => $factures->count(),
            'sale_day_id' => $saleDayId,
        ];

        return response()->json([
            "status" => "success",
            "factures" => $factures,
            "meta" => $meta,
        ]);
    }



}
