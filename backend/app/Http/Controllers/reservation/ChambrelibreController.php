<?php

namespace App\Http\Controllers\reservation;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Chambre;

class ChambrelibreController extends Controller
{
    public function chambreLibre(Request $request){
        $emplacement = auth()->user()->emplacement;
    $chambreslibres = Chambre::where('statut', 'libre')
        ->where('emplacement_id', $emplacement->id)
        ->with(['reservations' => function($query) {
            $query->with(['client', 'facture.payments'])
                  ->where('statut',"en_attente")
                  ->orWhere('statut',"confirmée")
                  ->orderBy('date_debut', 'desc');
        }])
        ->get();
    
    return view('reservation.chambrelibre', compact('chambreslibres'));
    }
    public function chambreOccupee(Request $request){
        $emplacement = auth()->user()->emplacement;
    $chambresoccupees = Chambre::where('statut', 'occupée')
        ->where('emplacement_id', $emplacement->id)
        ->with(['reservations' => function($query) {
            $query->with(['client', 'facture.payments'])
                  ->where('statut',"confirmée")
                  ->orderBy('date_debut', 'desc');
        }])
        ->get();
    return view('reservation.chambreoccupee', compact('chambresoccupees'));
}
   public function chambreReserve(Request $request){
        $emplacement = auth()->user()->emplacement;
    $chambresreservees = Chambre::whereHas('reservations', function($query) {
            $query->where('statut', 'en_attente')
                  ->orWhere('statut', 'confirmée');
        })
        ->where('emplacement_id', $emplacement->id)
        ->with(['reservations' => function($query) {
            $query->with(['client', 'facture.payments'])
                  ->where('statut',"en_attente")
                  ->orWhere('statut',"confirmée")
                  ->orderBy('date_debut', 'desc');
        }])
        ->get();
    
    return view('reservation.chambereserve', compact('chambresreservees'));
   }
}