<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SessionLog extends Model
{
    use HasFactory;

    protected $table = 'session_logs';
    protected $fillable = ['session_id','action','performed_by','reason'];

    public function session()
    {
        return $this->belongsTo(DaySession::class, 'session_id');
    }
}
