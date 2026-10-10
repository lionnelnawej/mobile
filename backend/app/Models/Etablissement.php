<?php

namespace App\Models;

use App\Models\SellData;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Etablissement extends Model
{
    use HasFactory;

    protected $primaryKey = 'id';


    protected $fillable = [
        'nom',
        'type',
        'adresse',
        'telephone',
        'token',
    ];

    public function users()
    {
        return $this->hasMany(User::class);
    }


    public function licence(){
        return $this->hasOne(Licence::class, "ets_id", "id");
    }

    public function liaison(){
        return $this->hasOne(LiaisonData::class, "ets_id", "id");
    }
    public function sellDatas()
{
    return $this->hasMany(SellData::class, 'ets_id', 'id');
}
public function journees()
{
    return $this->hasMany(SaleDay::class, 'ets_id', 'id');
}
}
