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
use App\Http\Controllers\reservation\ReservationController;
use App\Http\Controllers\SettingController;
use App\Http\Controllers\SettingController as ControllersSettingController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\ShiftController;
use App\Http\Controllers\ShiftSessionController;
use App\Http\Controllers\Admin\InventoryController as AdminInventoryController;
use App\Http\Controllers\ProductController as ControllersProductController;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\MobileAuthController;
use App\Http\Controllers\factureFactureController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Routes from `web.php` that act as API endpoints have been moved here and
| grouped by user type (caissier, serveur, admin) and by functionality.
| Per-route middleware was removed as requested; protect these routes via
| global API middleware (auth, scopes, etc.) in `RouteServiceProvider` or
| via a group middleware if desired.
|
*/

// Mobile login (user_id-only)
Route::post('/mobile/login', [MobileAuthController::class, 'loginMobile']);
// Mobile login with email + password
Route::post('/login', [MobileAuthController::class, 'loginEmail']);

// API routes: apply CORS and allow impersonation via `user_id` (X-User-Id header or user_id param)
Route::middleware(['cors','user.by_id'])->group(function (){

	// Mobile-friendly endpoints (menu, areas, tables, orders lifecycle)
	Route::get('/categories', [ProductController::class, 'getAllCategories']);
	Route::get('/products', [ProductController::class, 'getAllProducts']);
	Route::get('/areas', [AdminController::class, 'getAllEmplacements']);
	Route::get('/tables', [AdminController::class, 'getAllTables']);

	// Orders flows (create/update/merge/print/pay)
	Route::get('/orders/active', [commandesController::class, 'index']);
	Route::post('/orders', [HomeController::class, 'saveFacture']);
	Route::put('/orders/{id}', [commandesController::class, 'update']);
	Route::patch('/orders/{id}/table', function(\Illuminate\Http\Request $request, $id){
		// forward to AdminController::triggerTableOperation as a 'transfert' operation
		$r = $request->merge(['op'=>'transfert','facture_id'=>$id]);
		return app(\App\Http\Controllers\AdminController::class)->triggerTableOperation($r);
	});
	Route::post('/orders/merge', [factureFactureController::class, 'fusionner']);
	Route::get('/orders/{id}', [CommandeController::class, 'getCommandeDetails']);
	Route::post('/orders/{id}/print', [CommandeController::class, 'getCommandeDetails']);
	Route::post('/orders/{id}/pay', function(\Illuminate\Http\Request $request, $id){
		$ets_id = $request->query('ets_id') ?? $request->input('ets_id');
		$r = $request->merge(['facture_id'=>$id, 'ets_id'=>$ets_id]);
		return app(\App\Http\Controllers\AdminController::class)->createPayment($r);
	});


	// CAISSIER endpoints (payments, factures, sales)
	Route::prefix('caissier')->group(function(){
		Route::post('/facture.create', [HomeController::class, 'saveFacture']);
		Route::post('/factures.link', [HomeController::class, 'linkFactures']);
		Route::get('/factures.all', [HomeController::class, 'getAllFacturesCmds']);
		Route::get('/sells.all', [HomeController::class, 'getAllSells']);
		Route::get('/counts.all', [HomeController::class, 'dashboardCounter']);
		Route::post('/payment.create', [AdminController::class, 'createPayment']);
		Route::post('/reservation.pay', [ReservationController::class, 'payerReservation']);
	});

	// SERVEUR endpoints (orders, commandes, serveurs info)
	Route::prefix('serveur')->group(function(){
		Route::get('/orders', [commandesController::class, 'index']);
		Route::get('/commandes/servir/{id}', [commandesController::class, 'servir']);
		Route::get('/commandes/edit/{id}', [commandesController::class, 'edit']);
		Route::put('/commandes/{id}', [commandesController::class, 'update']);
		Route::get('/serveurs.all', [AdminController::class, 'getAllServeurs']);
		Route::get('/serveurs.services', [AdminController::class, 'getAllServeursServices']);
	});

	// ADMIN endpoints (users, shifts, products, inventory, emplacements, reports)
	Route::prefix('admin')->group(function(){
		Route::post('/create.account', [UserController::class, 'createEtsAccount']);

		// Day operations
		Route::post('/day.start', [AdminController::class, 'startDay']);
		Route::post('/day.close.report', [AdminController::class, 'closeDayReport']);
		Route::post('/day.close', [AdminController::class, 'closeDay']);
		Route::get('/caisse.day.report/{sale_day_id}', [AdminController::class, 'generatePDF']);

		// Shifts management
		Route::get('/shifts', [ShiftController::class, 'index']);
		Route::get('/shifts/list', [ShiftController::class, 'list']);
		Route::post('/shifts/pattern', [ShiftController::class, 'storePattern']);
		Route::post('/shifts/assign', [ShiftController::class, 'assignEmployee']);
		Route::post('/shifts/override', [ShiftController::class, 'createOverride']);
		Route::post('/shifts/absence', [ShiftController::class, 'createAbsence']);
		Route::post('/shifts/assignment.delete', [ShiftController::class, 'deleteAssignment']);
		Route::post('/shifts/override.delete', [ShiftController::class, 'deleteOverride']);
		Route::post('/shifts/absence.delete', [ShiftController::class, 'deleteAbsence']);

		// Session endpoints
		Route::post('/session/open', [ShiftSessionController::class, 'open']);
		Route::post('/session/close', [ShiftSessionController::class, 'close']);
		Route::post('/session/admin-close', [ShiftSessionController::class, 'adminClose']);
		Route::get('/session/status', [ShiftSessionController::class, 'status']);

		// Users and permissions
		Route::get('/users.all', [AdminController::class, 'getAllUsersWithLatestLog']);
		Route::get('/users', [AdminController::class, 'getAllUsersWithLatestLog']);
		Route::post('/user.delete', function(Request $request){
			$uid = $request->user_id;
			$user = User::find((int)$uid);
			if($user && $user->role !== 'admin'){
				$user->update(['status'=>'deleted']);
				return response()->json(["status"=>"success","message"=>"Utilisateur supprimé avec succès !"]);
			}
			else{
				return response()->json(["errors"=> "Echec de suppression !"], 400);
			}
		});

		Route::get('/permissions', [AdminController::class, 'getAllPermissions']);
		Route::post('/user.give.access', [AdminController::class, 'updateUserPermissions']);
		Route::post('/user.create', [UserController::class, 'createUser']);

		// Product management
		Route::post('/categorie.create', [ProductController::class, 'createCategory']);
		Route::get('/categories.all', [ProductController::class, 'getAllCategories']);
		Route::post('/product.create', [ProductController::class, 'createProduct']);
		Route::post('/product.update.quantified', [ProductController::class, 'updateProductQuantified']);
		Route::post('/product.update.tva', [ProductController::class, 'updateProductTva']);
		Route::get('/products.all', [ProductController::class, 'getAllProducts']);
		Route::post('/mvt.create', [ProductController::class, 'createStockMvt']);
		Route::post('/mvt.entree', [ProductController::class, 'entreeStockMvt']);
		Route::get('/mvts.all', [ProductController::class, 'getStockMvts']);
		Route::post('/mvts.delete', [ProductController::class, 'deleteMvt']);

		// Inventory
		Route::post('/inventory.start', [InventoryController::class, 'startInventory']);
		Route::get('/inventories.all', [InventoryController::class, 'getInventoriesHistory']);
		Route::post('/inventory.validate', [InventoryController::class, 'validateInventory']);
		Route::get('/inventory.current', [InventoryController::class, 'getCurrentInventory']);
		Route::post('/inventory.delete', [InventoryController::class, 'deleteInventory']);
		Route::get('/inventory.products', [InventoryController::class, 'getAllProductsWithStock']);

		// Emplacements & tables
		Route::post('/emplacement.create', [AdminController::class, 'createEmplacement']);
		Route::get('/emplacements.all', [AdminController::class, 'getAllEmplacements']);
		Route::post('/table.create', [AdminController::class, 'createTable']);
		Route::get('/tables.all', [AdminController::class, 'getAllTables']);
		Route::post('/table.operation', [AdminController::class, 'triggerTableOperation']);
		Route::post('/table.liberer', [AdminController::class, 'libererTable']);
		Route::post('/cmd.servir', [AdminController::class, 'servirCommande']);
		Route::post('/chambre.status', [AdminController::class, 'updateBedRoomStatus']);

		// Reports
		Route::get('/reports.all', [AdminController::class, 'viewGlobalReports']);
		Route::get('/report.detail', [AdminController::class, 'showDaySaleFacturesByCaissier']);
		Route::get('/reports.service.vente', [VentreSrviceController::class, 'index']);
		Route::get('/reports/service/vente/emplacement/{emplacement_id}', [VentreSrviceController::class, 'showEmplacementSales']);
		Route::get('/reports/service/vente/details/{id_saleDay}/{emplacement_id}', [VentreSrviceController::class, 'showSaleDetails']);
		Route::get('/reports.performance', [PerfomanceUserController::class, 'index']);
		Route::get('/reports.produits', [ProduitController::class, 'index']);
		Route::get('/reports/produits-plus-vendus/{emplacement_id}', [ProduitController::class, 'showProduitsPlusVendus']);
		Route::get('/reports.commandes', [CommandeController::class, 'index']);
		Route::get('/reports/commandes/{id}', [CommandeController::class, 'getCommandeDetails']);
		Route::get('/reports.inventaires', [InventaireController::class, 'index']);
		Route::get('/reports.stocks', [InventaireController::class, 'stocks']);
		Route::get('/reports.Mouvements', [InventaireController::class, 'mouvementstock']);
		Route::get('/reports.finances', [financeController::class, 'finances']);
		Route::get('/reports/payment-details/{id}', [financeController::class, 'getPaymentDetails']);

		// Reservations
		Route::get('/reservations', [ReservationController::class, 'viewAllReservations']);
		Route::post('/reservation.create', [ReservationController::class, 'reserverChambre']);
		Route::post('/reservation.update', [ReservationController::class, 'modifierReservation']);
		Route::post('/reservation.extend', [ReservationController::class, 'extendReservationDay']);
		Route::get('/reservation.cancel/{id}', [ReservationController::class, 'annulerReservation']);
		Route::get('/reservation.facture/{id}', [ReservationController::class, 'getReservationFacture']);
		Route::get('/reservation.details/{id}', [ReservationController::class, 'getReservationDetails']);
		Route::get('/chambre.occuper/{chambreId}', [ReservationController::class, 'occupeChambre']);

		// Misc
		Route::post('/link.request', [SettingController::class, 'sendLinkRequest']);
		Route::get('/link.check', [SettingController::class, 'checkLink']);
	});

});
