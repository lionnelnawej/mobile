<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MouvementStock extends Model
{
    use HasFactory;

    protected $fillable = [
        "produit_id",
        "numdoc",
        "type_mouvement",
        "quantite",
        "source",
        "destination",
        "sale_day_id", 
        "date_mouvement",
        "user_id",
        "ets_id",
        "emplacement_id",
    ];


    public function facture(){
        return $this->belongsTo(Facture::class, 'numdoc');
    }

    public function produit(){
        return $this->belongsTo(Produit::class, 'produit_id');
    }

    public function user(){
        return $this->belongsTo(User::class, "user_id");
    }


    public function prov(){
        return $this->belongsTo(Emplacement::class, "source");
    }
    
    public function dest(){
        return $this->belongsTo(Emplacement::class, "destination");
    }
    public function emplacement(){
        return $this->belongsTo(Emplacement::class, "emplacement_id");
    }


    protected $casts = [
        'created_at'=>'datetime:d/m/Y H:i',
        'updated_at'=>'datetime:d/m/Y H:i',
        'date_mouvement'=>'datetime:Y-m-d',
    ];

    
}
