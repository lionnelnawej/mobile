<?php

namespace App\Models;

use App\Models\Produit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Inventaire extends Model
{
    use HasFactory;
    protected $fillable = [
        'date_debut',
        'date_fin',
        'admin_id',
        'ets_id',
        'emplacement_id',
        'comment',
        'status'
    ];

    public function admin()
    {
        return $this->belongsTo(User::class, 'admin_id');
    }
    public function etablissement()
    {
        return $this->belongsTo(Etablissement::class, 'ets_id');
    }
    public function emplacement()
    {
        return $this->belongsTo(Emplacement::class, 'emplacement_id');
    }
    public function produit()
    {
    return $this->belongsTo(Produit::class);
    }


    public function details(){
        return $this->hasMany(InventoryDetail::class, "inventory_id", "id");
    }

}
