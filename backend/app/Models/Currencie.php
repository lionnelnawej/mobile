<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Currencie extends Model
{
    use HasFactory;
    protected $primaryKey = 'id';

    protected $fillable = [
        "currencie_date",
        "currencie_value",
        "currencie_exchange",
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
        'currencie_date'=>'datetime:d/m/Y',
    ];

    /**
     * The attributes that should be mutated to dates.
     *
     * @var array
     */
    protected $dates = [
        'created_at',
        'updated_at',
        'currencie_date',
    ];
}
