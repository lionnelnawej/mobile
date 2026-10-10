<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Reservation extends Model
{
    use HasFactory;
    protected $primaryKey = 'id';

    protected $fillable = [
        "chambre_id",
        "table_id",
        "client_id",
        "date_debut",
        "date_fin",
        "statut",
        "ets_id",
        "emplacement_id"
    ];


    protected $casts = [
        'created_at'=>'datetime:d/m/Y H:i',
        'date_debut'=>'date:Y-m-d',
        'date_fin'=>'date:Y-m-d',
    ];


    public function chambre(){
       return $this->belongsTo(Chambre::class, "chambre_id");
    } 
    public function table(){
        return $this->belongsTo(RestaurantTable::class, "table_id");
    }
    
    public function facture(){
        return $this->hasOne(Facture::class, "reservation_id", "id");
    }

    public function client(){
        return $this->belongsTo(Client::class, "client_id");
    }

    

}
