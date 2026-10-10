<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class InventoryDetail extends Model
{
    use HasFactory;
    protected $fillable = [
        'produit_id',
        'quantite_physique',
        'quantite_theorique',
        'ecart',
        'observation',
        'inventory_id',
    ];

    public function produit()
    {
        return $this->belongsTo(Produit::class, 'produit_id');
    }
    public function inventory()
    {
        return $this->belongsTo(Inventaire::class, 'inventory_id');
    }

}
