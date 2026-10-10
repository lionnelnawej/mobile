<?php

namespace App\Http\Controllers\report;

use App\Models\SaleDay;
use App\Models\Emplacement;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class VentreSrviceController extends Controller
{
    public function index()
    {
        $emplacements = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->orderBy('libelle')
            ->where('type',"restaurant & lounge")
            ->get();
        return view('reports.service_sales',compact('emplacements'));
    }
    public function showEmplacementSales($emplacement_id)
    {
        $emplacement = Emplacement::where('ets_id', auth()->user()->ets_id)
            ->where('id', $emplacement_id)
            ->first();
        if (!$emplacement) {
            return redirect()->route('reports.service.vente')->with('error', 'Cet emplacement n\'existe pas.');
        }
        $saledays = SaleDay::with('factures')->paginate(15);
        return view('reports.service_sales_emplacement', compact('emplacement', 'saledays'));
    }
    public function showSaleDetails($id_saleDay, $emplacement_id)
    {
       $emplacement = Emplacement::where('ets_id', auth()->user()->ets_id)
        ->where('id', $emplacement_id)
        ->first();
        
    if (!$emplacement) {
        return redirect()->route('reports.service.vente')->with('error', 'Cet emplacement n\'existe pas.');
    }
    if($emplacement->factures->count() <=0){
        return redirect()->route('reports.service.vente')->with('error', 'Aucune vente trouvée pour cet emplacement.');
    }
    
    $saleday = SaleDay::with([
    'factures' => function($query) use ($emplacement_id) {
        $query->where('emplacement_id', $emplacement_id);
    },
    'factures.user',
    'factures.table',
    'factures.chambre', 
    'factures.details.produit.categorie',
    'factures.payments'
])
->where('id', $id_saleDay)
->first();
    
    if (!$saleday) {
        return redirect()->route('reports.service_sales.emplacement', ['emplacement_id' => $emplacement_id])
            ->with('error', 'Cette journée de vente n\'existe pas.');
    }
    if($saleday->ets_id != auth()->user()->ets_id){
        return redirect()->route('reports.service_sales.emplacement', ['emplacement_id' => $emplacement_id])->with('error', 'Vous n\'êtes pas autorisé à voir les détails de cette journée de vente.');
    }
    // si le nombre de factures pour cet emplacement est zéro, rediriger avec un message d'erreur
    if( $saleday->factures->where('emplacement_id', $emplacement_id)->where('statut','payée')->count() <=0){
        return redirect()->route('reports.service_sales.emplacement', ['emplacement_id' => $emplacement_id])->with('error', 'Aucune vente trouvée pour l\'emplacement ' . $emplacement->libelle . ' lors de cette journée de vente.');
    }
    return view('reports.service_sales_details', compact('saleday', 'emplacement'));
}
}
