<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'sale_day_id', 
        'log_date', 'logged_in_at', 'logged_out_at', 'status',
        'ets_id', 'emplacement_id'
    ];

    public function user()
    {
        return $this->belongsTo(User::class, "user_id");
    }

    public function saleDay()
    {
        return $this->belongsTo(SaleDay::class, "sale_day_id");
    }

     /**
     * The attributes that should be casted to native types.
     *
     * @var array
     */
    protected $casts = [
        'created_at'=>'datetime:d/m/Y H:i',
        'updated_at'=>'datetime:d/m/Y H:i',
        'log_date'=>'datetime:d/m/Y',
        'logged_in_at'=>'datetime:d/m/Y H:i',
        'logged_out_at'=>'datetime:d/m/Y H:i'
    ];

    /**
     * The attributes that should be mutated to dates.
     *
     * @var array
     */
    protected $dates = [
        'created_at',
        'updated_at',
        'log_date',
        'logged_in_at',
        'logged_out_at'
    ];
}
