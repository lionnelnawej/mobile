<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LiaisonData extends Model
{
    use HasFactory;
    protected $fillable = [
        "code_cpte", "token", "liaison_id", "ets_id", "status"
    ];
}
