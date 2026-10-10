<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\Commandes\commandesController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\InventoryController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\report\CommandeController;
use App\Http\Controllers\report\financeController;
use App\Http\Controllers\report\InventaireController;
use App\Http\Controllers\report\PerfomanceUserController;
use App\Http\Controllers\report\ProduitController;
use App\Http\Controllers\report\VentreSrviceController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\reservation\ChambrelibreController;
use App\Http\Controllers\reservation\ReservationController;
use App\Http\Controllers\SettingController;

//Nathan imports
use App\Http\Controllers\UserController;
use App\Http\Controllers\ShiftController;
use App\Http\Controllers\ShiftSessionController;
use App\Models\Categorie;
use App\Models\Emplacement;
use App\Models\MouvementStock;
use App\Models\Produit;
use App\Models\SaleDay;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;


/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/
//Auth::routes();
Auth::routes();
Route::post("/create.account", [UserController::class, "createEtsAccount"])->name("create.account");
Route::middleware(["auth", "check.day.access", "check.shift.access"])->group(function(){
    //rapports.ventes
    Route::get('/rapports.ventes', [ReportController::class, 'ventes'])->name('rapports.ventes');
    Route::get('reports/journee/{id}', [ReportController::class, 'showJournee'])->name('reports.journee.show');
    Route::get('reports/journee/{id}/print', [ReportController::class, 'printJournee'])->name('reports.journee.print');
    Route::get('/licence.payment', [UserController::class, 'redirectToPayment'])->name('licence.payment');
    Route::post('/licence.payment.confirm', [UserController::class, 'confirmPayment'])->name('licence.payment.confirm');
    Route::view('/', "home")->name("home");
    Route::view('/dashboard', "dashboard")->name("dashboard");
    Route::view('/settings', "settings")->name("settings");
    Route::post("day.start", [AdminController::class, "startDay"])->name("day.start")->middleware("can:ouvrir-journee");
    Route::post("day.close.report", [AdminController::class, "closeDayReport"])->name("day.close")->middleware("can:cloturer-journee");
    Route::get("/caisse.day.report/{sale_day_id}", [AdminController::class, "generatePDF"])->middleware("can:cloturer-journee");
    Route::post("day.close", [AdminController::class, "closeDay"])->name("day.close")->middleware("can:cloturer-journee");
    Route::view('/licences/pricing', "licences.pricing")->name("licences.pricing");

    Route::view('/orders', "orders")->name("orders");
    Route::get('/sells', fn()=>view("sells",["serveurs"=>User::where("ets_id", Auth::user()->ets_id)->get(), "saleDay"=>SaleDay::whereNull("end_time")->where("ets_id", Auth::user()->ets_id)->latest()->first()]))->name("sells");
    Route::view('/factures', "factures")->name("factures");
    Route::view('/serveurs', "serveurs")->name("serveurs");
    Route::view('/serveurs.activities', "serveurs_activities")->name("serveurs.activities");
    Route::view('/orders.portal', "serveur_portal")->name("orders.portal");
    Route::view('/orders.interface', "orders_interface")->name("orders.interface");

    Route::view('/products.categories', "product_categories")->name("products.categories");
    Route::get('/products.mvts', fn()=>view("products_mvts", ["produits"=>Produit::orderBy("libelle")->where("ets_id", Auth::user()->ets_id)->get(), "emplacements" => Emplacement::where("ets_id", Auth::user()->ets_id)->whereNot('type', 'hôtel')->get()]))->name("products.mvts");
    Route::get('/fiche_stock', [ProductController::class, 'getFicheStockData'])->name('fiche_stock');
    Route::get('/fiche_stock.pdf', [ProductController::class, 'exportFicheStockToPDF'])->name('fiche_stock.pdf');
    Route::get('/fiche_stock.excel', [ProductController::class, 'exportFicheStockToExcel'])->name('fiche_stock.excel');
    Route::get('/products', fn()=>view("products", [
        "categories"=>Categorie::where("ets_id", Auth::user()->ets_id)->get(),
        "emplacements"=>Emplacement::where("ets_id", Auth::user()->ets_id)->whereNot("type", "hôtel")->get(),
    ]))->name("products");

    Route::get('/products.inventories', fn()=>view("products_inventories", [
        "emplacements"=>Emplacement::where("ets_id", Auth::user()->ets_id)->whereNot("type", "hôtel")->get()
    ]))->name("products.inventories");

    Route::view('/tables.occuped', "tables_occuped")->name("tables.occuped");
    Route::view('/beds.occuped', "bedroom_occuped")->name("beds.occuped");
    Route::view('/tables.emplacements', "emplacements")->name("tables.emplacements");
    Route::view('/tables', "tables")->name("tables");
    Route::view('/reports.global', "reports_global")->name("reports.global");

     Route::get('/users', function(){
        $places = Emplacement::where("ets_id", Auth::user()->ets_id)->get();
        return view("users", ["emplacements"=>$places]);
    })->name("users");

    // Shifts management (admin)
    Route::get('/admin/shifts', [ShiftController::class, 'index'])->name('shifts.index')->middleware('can:modifier-utilisateurs');
    Route::get('/admin/shifts/list', [ShiftController::class, 'list'])->name('shifts.list')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/pattern', [ShiftController::class, 'storePattern'])->name('shifts.pattern.create')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/assign', [ShiftController::class, 'assignEmployee'])->name('shifts.assign')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/override', [ShiftController::class, 'createOverride'])->name('shifts.override')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/absence', [ShiftController::class, 'createAbsence'])->name('shifts.absence')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/assignment.delete', [ShiftController::class, 'deleteAssignment'])->name('shifts.assignment.delete')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/override.delete', [ShiftController::class, 'deleteOverride'])->name('shifts.override.delete')->middleware('can:modifier-utilisateurs');
    Route::post('/admin/shifts/absence.delete', [ShiftController::class, 'deleteAbsence'])->name('shifts.absence.delete')->middleware('can:modifier-utilisateurs');
    // Day session endpoints (open/close/status)
    Route::post('/session/open', [ShiftSessionController::class, 'open'])->name('session.open');
    Route::post('/session/close', [ShiftSessionController::class, 'close'])->name('session.close');
    Route::post('/session/admin-close', [ShiftSessionController::class, 'adminClose'])->name('session.admin.close')->middleware('can:cloturer-journee');
    Route::get('/session/status', [ShiftSessionController::class, 'status'])->name('session.status');
    //GET ALL USER WITH LATEST LOGS

    Route::get("users.all", [AdminController::class, "getAllUsersWithLatestLog"])->name("users.all")->middleware("can:voir-utilisateurs");
    Route::get("serveurs.all", [AdminController::class, "getAllServeurs"])->name("serveurs.all")->middleware("can:voir-serveurs");
    Route::get("/serveurs.services", [AdminController::class, "getAllServeursServices"])->name("serveurs.services");

    Route::post("/user.delete", function(Request $request){
        $uid = $request->user_id;
        $user = User::find((int)$uid);
        if($user && $user->role !== 'admin'){
            $user->update([
                'status'=>'deleted'
            ]);
            return response()->json([
                "status"=>"success",
                "message"=>"Utilisateur supprimé avec succès !"
            ]);
        }
        else{
            return response()->json(["errors"=> "Echec de suppression !"]);
        }
    })->name("user.delete")->middleware('can:supprimer-utilisateurs');

    //GET ALL PERMISSIONS
    Route::get("/permissions", [AdminController::class, "getAllPermissions"])->name("users.all");
    Route::post("/user.give.access", [AdminController::class, "updateUserPermissions"])->name("user.give.access")->middleware("can:modifier-utilisateurs");
    Route::post("/user.create", [UserController::class, "createUser"])->name("user.create")->middleware("can:creer-utilisateurs");

    //==========PRODUCT MANAGEMENT===============//
    Route::post("/categorie.create", [ProductController::class, "createCategory"])->name("categorie.create")->middleware("can:creer-categories");
    Route::get("/categories.all", [ProductController::class, "getAllCategories"])->name("categories.all")->middleware("can:voir-categories");
    Route::post("/product.create", [ProductController::class, "createProduct"])->name("product.create")->middleware("can:creer-produits");
    Route::get("/products.entree", function(){
        $products = Produit::where("ets_id", Auth::user()->ets_id)->orderBy("libelle", "ASC")->get();
        $emplacements = Emplacement::where("ets_id", Auth::user()->ets_id)->whereNot("type", "hôtel")->orderBy("libelle", "ASC")->get();
        return view("products_entree", ["produits"=>$products, "emplacements"=>$emplacements]);
    })->name("products.entree")->middleware("can:creer-produits");
    Route::post("/product.update.quantified", [ProductController::class, "updateProductQuantified"])->name("product.update.quantified")->middleware("can:modifier-produits");
    Route::post("/product.update.tva", [ProductController::class, "updateProductTva"])->name("product.update.tva")->middleware("can:modifier-produits");
    Route::get("/products.all", [ProductController::class, "getAllProducts"])->name("products.all")->middleware("can:voir-produits");
    Route::post("/mvt.create", [ProductController::class, "createStockMvt"])->name("mvt.create")->middleware("can:creer-mouvements-stock");
    Route::post("/mvt.entree", [ProductController::class, "entreeStockMvt"])->name("mvt.entree")->middleware("can:creer-mouvements-stock");
    Route::get("/mvts.all", [ProductController::class, "getStockMvts"])->name("mvts.all")->middleware("can:voir-mouvements-stock");
    Route::post("/mvts.delete", [ProductController::class, "deleteMvt"])->name("mvts.delete")->middleware("can:supprimer-mouvements-stock");

    ///==========EMPLACEMENTS & TABLES MANAGEMENTS=======/
    Route::post("/inventory.start", [InventoryController::class, "startInventory"])->name("inventory.start");
    Route::get("/inventories.all", [InventoryController::class, "getInventoriesHistory"])->name("inventories.all");
    Route::post("/inventory.validate", [InventoryController::class, "validateInventory"])->name("inventory.validate");
    Route::get("/inventory.current", [InventoryController::class, "getCurrentInventory"])->name("inventory.current");
    Route::post("/inventory.delete", [InventoryController::class, "deleteInventory"])->name("inventory.delete");
    Route::get("/inventory.products", [InventoryController::class, "getAllProductsWithStock"])->name("inventory.products");

    ///==========EMPLACEMENTS & TABLES MANAGEMENTS=======//
    Route::post("/emplacement.create", [AdminController::class, "createEmplacement"])->name("emplacement.create")->middleware("can:creer-emplacements");
    Route::get("/emplacements.all", [AdminController::class, "getAllEmplacements"])->name("emplacements.all")->middleware("can:voir-emplacements");
    Route::post("/table.create", [AdminController::class, "createTable"])->name("table.create")->middleware("can:creer-tables");
    Route::get("/tables.all", [AdminController::class, "getAllTables"])->name("tables.all")->middleware("can:voir-tables");
    Route::post("/table.operation", [AdminController::class, "triggerTableOperation"])->name("table.operation")->middleware("can:voir-tables");
    Route::post("/table.liberer", [AdminController::class, "libererTable"])->name("table.liberer");
    Route::post("/cmd.servir", [AdminController::class, "servirCommande"])->name("cmd.servir");
    Route::post("/chambre.status", [AdminController::class, "updateBedRoomStatus"])->name("chambre.status");
    ///==========PAYMENT & INVOICE=============//
    Route::post("/payment.create", [AdminController::class, "createPayment"])->name("payment.create");
    Route::get("/reports.all", [AdminController::class, "viewGlobalReports"])->name("reports.all");
    Route::get("/report.detail", [AdminController::class, "showDaySaleFacturesByCaissier"])->name("report.detail");
    Route::post("/facture.create", [HomeController::class, "saveFacture"])->name("facture.create")->middleware("can:creer-factures");
    Route::post("/factures.link", [HomeController::class, "linkFactures"])->name("factures.link")->middleware("can:creer-factures");
    Route::get("/factures.all", [HomeController::class, "getAllFacturesCmds"])->name("factures.all")->middleware("can:voir-factures");
    Route::get("/sells.all", [HomeController::class, "getAllSells"])->name("sells.all")->middleware("can:voir-ventes");
    Route::get("/counts.all", [HomeController::class, "dashboardCounter"])->name("counts.all");

    //============Module pour les hotel===================//
    Route::view("/bedroom.reserve", "hotel_reservation")->name("bedroom.reserve")->can("voir-chambres");
    Route::post("/reservation.action", [AdminController::class, "reserverChambreOrTable"])->name("reservation.action");
    Route::get("/chambres.all", [AdminController::class, "getAllChambres"])->name("chambres.all")->can("voir-chambres");

    //NATHAN ROUTES
    Route::get("/reports.service.vente", [VentreSrviceController::class, "index"])->name("reports.service.vente");

    Route::get("/reports/service/vente/emplacement/{emplacement_id}", [VentreSrviceController::class, "showEmplacementSales"])->name("reports.service_sales.emplacement");
    Route::get("/reports/service/vente/details/{id_saleDay}/{emplacement_id}", [VentreSrviceController::class, "showSaleDetails"])->name("reports.service.vente.details");
    //reports.performance
    Route::get("/reports.performance", [PerfomanceUserController::class, "index"])->name("reports.performance");
    //reports.produits
    Route::get("/reports.produits", [ProduitController::class, "index"])->name("reports.produits");
    Route::get('/reports/produits-plus-vendus/{emplacement_id}', [ProduitController::class, 'showProduitsPlusVendus'])->name('reports.produits.plusVendus.details');
    //reports.commandes
    Route::get("/reports.commandes", [CommandeController::class, "index"])->name("reports.commandes");
    // Route::get('/api/commandes/{commande}/details', [ReportController::class, 'getCommandeDetails']);
    Route::get('/reports/commandes/{id}', [CommandeController::class, 'getCommandeDetails'])->name('reports.commandes.details');
    //reports.inventaires
    Route::get('/reports.inventaires', [InventaireController::class, 'index'])->name('reports.inventaires');
    //reports.stocks
    Route::get('/reports.stocks', [InventaireController::class, 'stocks'])->name('reports.stocks');
    //reports.Mouvements
    Route::get('/reports.Mouvements', [InventaireController::class, 'mouvementstock'])->name('reports.Mouvements');
    //reports.finances
    Route::get('/reports.finances', [financeController::class, 'finances'])->name('reports.finances');
    Route::get('/reports/payment-details/{id}', [financeController::class, 'getPaymentDetails'])->name('reports.payment-details');
    //=============Reservation Hotel =============//


    //Reservations
    Route::get('/reservations', function(){
        $places = Emplacement::where("ets_id", Auth::user()->ets_id)->where("type", "hôtel")->get();
        return view('reservation.reservations', [
            "emplacements"=> $places
        ]);
    })->name("reservations");
    //reservation.created
    Route::get('/reservations.all', [ReservationController::class, "viewAllReservations"])->name("reservations.all");

    Route::get('/reservation.created', [ReservationController::class, "createReservationView"])->name("reservation.created");
    //reservation.create
    Route::post('/reservation.create', [ReservationController::class, "reserverChambre"])->name("reservation.create");

    Route::post('/reservation.update', [ReservationController::class, "modifierReservation"])->name("reservation.update");

    // Ajoute des jours à une reservation des chambres existantes
    Route::post('/reservation.extend', [ReservationController::class, "extendReservationDay"])->name("reservation.extend");

    Route::post('/reservation.pay', [ReservationController::class, "payerReservation"])->name("reservation.pay");

    Route::get('/reservation.cancel/{id}', [ReservationController::class, "annulerReservation"])->name("reservation.cancel");

    Route::get('/reservation.facture/{id}', [ReservationController::class, "getReservationFacture"])->name("reservation.facture");

    Route::get('/reservation.details/{id}', [ReservationController::class, "getReservationDetails"])->name("reservation.details");


    Route::get('/chambre.occuper/{chambreId}', [ReservationController::class, "occupeChambre"])->name("chambre.occuper");

    Route::get("/chambres/{name}", function($name){
        request()->route()->name("chambres.$name");
        return view("reservation.chambres", compact("name"));
    })->whereIn("name", ["libre", "occupee", "reservee", "all"]);

    Route::get('/commandes', [commandesController::class, "index"])->name("commandes");
    //servir.ok
    Route::get('/commandes/servir/{id}', [commandesController::class, "servir"])->name("servir.ok");
    //edit
    Route::get('/commandes/edit/{id}', [commandesController::class, "edit"])->name("servir.edit");
    Route::put('/commandes/{id}', [CommandesController::class, 'update'])->name('commandes.update');



    //Liaison des données au module de la cpté
    Route::post("/link.request", [SettingController::class, "sendLinkRequest"])->name("link.request");
    Route::get("/link.check", [SettingController::class, "checkLink"])->name("link.check");

});
//route pour la cuisine
Route::get("/cuisine", fn()=>view("cuisine", ["tables"=>Emplacement::where("ets_id", Auth::user()->ets_id)->where("type", "table")->get()]))->name("cuisine")->middleware("auth");

