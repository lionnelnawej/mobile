<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class HotelData extends Model
{
    use HasFactory;
    protected $fillable = [
        'code_societe',
        'date_cloture',
        'total_chambre',
        'montant_theorique',
        'montant_encaisse',
        'ecart_caisse',
        'cash',
        'mobile_money',
        'carte',
        'caissier',
        'liaison_id',
        'ets_id',
    ];
}
