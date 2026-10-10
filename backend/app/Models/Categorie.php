<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Categorie extends Model
{
    use HasFactory;

    protected $fillable = [
        "libelle",
        "code",
        "type_service",
        "couleur",
        "ets_id"
    ];

    public function produits(){
        return $this->hasMany(Produit::class, "categorie_id", "id");
    }
}
