<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Client extends Model
{
    use HasFactory;

    protected $fillable = [
        "nom",
        "telephone",
        "email",
        "identite",
        "identite_type",
    ];


    public function reservations(){
        return $this->hasMany(Reservation::class, "client_id", "id");
    }
}
