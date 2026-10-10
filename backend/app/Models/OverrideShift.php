<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OverrideShift extends Model
{
    use HasFactory;

    protected $table = 'override_shifts';

    protected $fillable = [
        'user_id', 'date', 'autorise_par', 'raison', 'autorise'
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function autorisePar()
    {
        return $this->belongsTo(User::class, 'autorise_par');
    }
}
