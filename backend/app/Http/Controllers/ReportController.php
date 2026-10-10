<?php

namespace App\Http\Controllers;

use App\Models\SaleDay;
use Illuminate\Http\Request;

class ReportController extends Controller
{
   public function ventes()
    {
        $journees = auth()->user()
            ->etablissement
            ->journees()
            ->with('factures.details.produit')
            ->orderBy("created_at", "desc")
            ->paginate(10);
        
        // Calculer le total des ventes pour chaque journée
        foreach ($journees as $journee) {
            $journee->total_ventes = $journee->factures->sum('total_ttc');
        }

        return view('reports.ventes', compact('journees'));
    }

    public function showJournee($id)
    {
        $journee = SaleDay::with(['factures.details.produit', 'factures.payments'])
            ->findOrFail($id);
        
        // Vérifier que la journée appartient à l'établissement de l'utilisateur
        if ($journee->ets_id != auth()->user()->ets_id) {
            abort(403);
        }

        $total_journee = $journee->factures->sum('total_ttc');
        
        return view('reports.journee-details', compact('journee', 'total_journee'));
    }

    public function printJournee($id)
    {
        $journee = SaleDay::with(['factures.details.produit', 'factures.payments'])
            ->findOrFail($id);
        
        if ($journee->ets_id != auth()->user()->ets_id) {
            abort(403);
        }

        $total_journee = $journee->factures->sum('total_ttc');
        
        return view('reports.print-journee', compact('journee', 'total_journee'));
    }
}
