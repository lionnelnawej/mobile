<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EmployeeShift extends Model
{
    use HasFactory;

    protected $fillable = [
        'employee_id', 'shift_pattern_id', 'date_debut', 'ets_id'
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'employee_id');
    }

    public function pattern()
    {
        return $this->belongsTo(ShiftPattern::class, 'shift_pattern_id');
    }
}
