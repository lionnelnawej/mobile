<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payments extends Model
{
    use HasFactory;

    protected $fillable = [
        "amount",
        "devise",
        "mode",
        "mode_ref",
        "pay_date",
        "emplacement_id",
        "facture_id",
        "table_id",
        "chambre_id",
        "caissier_id",
        "sale_day_id",
        "user_id",
        "ets_id",
    ];

    public function facture(){
        return $this->belongsTo(Facture::class, "facture_id");
    }
    public function table(){
        return $this->belongsTo(RestaurantTable::class, "table_id");
    }
    public function chambre(){
        return $this->belongsTo(RestaurantTable::class, "chambre_id");
    }
    public function caisse(){
        return $this->belongsTo(RestaurantTable::class, "caisse_id");
    }
    public function user(){
        return $this->belongsTo(User::class, "user_id");
    }
    
    public function emplacement(){
        return $this->belongsTo(Emplacement::class, "emplacement_id"); // Relation manquante
    }
}
