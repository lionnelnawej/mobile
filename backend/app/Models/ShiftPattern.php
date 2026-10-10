<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShiftPattern extends Model
{
    use HasFactory;

    protected $fillable = [
        'nom', 'jours_travail', 'jours_repos', 'start_time', 'tolerance_before', 'tolerance_after', 'ets_id'
    ];

    public function employeeShifts()
    {
        return $this->hasMany(EmployeeShift::class, 'shift_pattern_id');
    }
}
