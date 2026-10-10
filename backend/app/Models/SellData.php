<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SellData extends Model
{
    use HasFactory;
    
    protected $fillable = [
        'code_societe',
        'date_cloture',
        'total_ventes_ht',
        'tva_16',
        'total_ventes_ttc',
        'montant_theorique',
        'montant_encaisse',
        'ecart_caisse',
        'cash',
        'mobile_money',
        'carte',
        'caissier',
        'ets_id',
        'liaison_id',
    ];
}
