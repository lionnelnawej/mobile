<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FactureDetail extends Model
{
    use HasFactory;
    protected $fillable = [
        'facture_id',
        'produit_id',
        'quantite',
        'prix_unitaire',
        'total_ligne',
    ];

    // Relations

    // Chaque détail appartient à une facture
    public function facture()
    {
        return $this->belongsTo(Facture::class, "facture_id");
    }

    // Chaque détail est lié à un produit
    public function produit()
    {
        return $this->belongsTo(Produit::class, "produit_id");
    }
}