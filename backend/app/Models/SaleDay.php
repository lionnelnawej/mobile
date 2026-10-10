<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SaleDay extends Model
{
    use HasFactory;
    protected $primaryKey = 'id';

    protected $fillable = [
        "sale_date",
        "start_time",
        "end_time",
        "ets_id"
    ];
      
    /**
     * The attributes that should be casted to native types.
     *
     * @var array
     */
    protected $casts = [
        'created_at'=>'datetime:d/m/Y H:i',
        'updated_at'=>'datetime:d/m/Y H:i',
        'start_time'=>'datetime:d/m/Y H:i',
        'end_time'=>'datetime:d/m/Y H:i',
        'sale_date'=>'datetime:d/m/Y',
    ];

    /**
     * The attributes that should be mutated to dates.
     *
     * @var array
     */
    protected $dates = [
        'created_at',
        'updated_at',
        'sale_date',
        'start_time',
        'end_time',
    ];


    public function factures(){
        return $this->hasMany(Facture::class, "sale_day_id", "id");
    }
    
    public function sales(){
        return $this->hasMany(MouvementStock::class, "sale_day_id", "id");
    }

    public function logs(){
        return $this->hasMany(UserLog::class, "sale_day_id", "id");
    }

}
