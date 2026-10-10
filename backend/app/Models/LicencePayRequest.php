<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LicencePayRequest extends Model
{
    use HasFactory;
    protected $fillable = [
        'ets_id',
        'uuid',
        'amount',
        'months',
        'status'
    ];
}
