<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CaisseReport extends Model
{
    use HasFactory;
    protected $fillable = [
        "serveur_id", 
        "caissier_id",
        "sale_day_id",
        "rapport_date",
        "valeur_theorique",
        "total_especes",
        "tickets_emis",
        "tickets_serveur",
        "taux"
    ];

    public function serveur(){
        return $this->belongsTo(User::class, "serveur_id");
    }

    public function caissier(){
        return $this->belongsTo(User::class, "caissier_id");
    }

    public function saleDay(){
        return $this->belongsTo(SaleDay::class, "sale_day_id");
    }
}
