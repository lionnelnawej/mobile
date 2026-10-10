<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RestaurantTable extends Model
{
    use HasFactory;

    protected $primaryKey = 'id';

    protected $fillable = [
        "numero",
        "emplacement_id",
        "statut",
        "ets_id"
    ];

    public function emplacement(){
        return $this->belongsTo(Emplacement::class, "emplacement_id");
    }

    public function commandes(){
        return $this->hasMany(Facture::class, "table_id", "id");
    }
    public function hotelCommandes(){
        return $this->hasMany(Facture::class, "chambre_id", "id");
    }
}
