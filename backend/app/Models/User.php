<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Models\SellData;
use App\Notifications\ResetPasswordNotification;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable, HasRoles;

    // Optionnel mais conseillé pour éviter les soucis de guard
    protected $guard_name = 'web';

    protected $fillable = [
        'name', 'email', 'password', 'actif', 'salaire','role', 'ets_id','emplacement_id', 'status'
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'actif' => 'boolean',
        'salaire' => 'decimal:2',
    ];


    public function etablissement()
    {
        return $this->belongsTo(Etablissement::class, "ets_id");
    }
    public function emplacement()
    {
        return $this->belongsTo(Emplacement::class, "emplacement_id");
    }

    // 🔹 Relation vers les logs
    public function logs()
    {
        return $this->hasMany(UserLog::class, 'user_id');
    }

    public function lastLog()
    {
        return $this->hasOne(UserLog::class, 'user_id')->latest('log_date');
    }


    public function sendPasswordResetNotification($token)
    {
        $this->notify(new ResetPasswordNotification($token));
    }
    public function ventes()
{
    return $this->hasMany(SellData::class, 'caissier');
}

    // Shift relations
    public function employeeShifts()
    {
        return $this->hasMany(EmployeeShift::class, 'employee_id');
    }

    public function overrides()
    {
        return $this->hasMany(OverrideShift::class, 'user_id');
    }

    public function absences()
    {
        return $this->hasMany(Absence::class, 'user_id');
    }
}
