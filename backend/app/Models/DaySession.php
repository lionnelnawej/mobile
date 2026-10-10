<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
    use App\Models\SessionLog;

class DaySession extends Model
{
    use HasFactory;

    protected $table = 'day_sessions';
    protected $fillable = ['user_id','opened_by','opened_at','closed_by','closed_at','notes'];

    protected $dates = ['opened_at','closed_at','created_at','updated_at'];

    public function logs()
    {
        return $this->hasMany(SessionLog::class, 'session_id');
    }
}
