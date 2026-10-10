<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Models\DaySession;
use App\Models\SessionLog;
use App\Models\EmployeeShift;
use Carbon\Carbon;

class ShiftSessionController extends Controller
{
    // Open a session for current user
    public function open(Request $request)
    {
        $user = Auth::user();
        if(!$user) return response()->json(['errors'=>'Unauthorized'], 401);

        $existing = DaySession::where('user_id',$user->id)->whereNull('closed_at')->first();
        if($existing) return response()->json(['status'=>'error','message'=>'Session déjà ouverte'], 422);

        $s = DaySession::create([
            'user_id'=>$user->id,
            'opened_by'=>$user->id,
            'opened_at'=>Carbon::now(),
        ]);
        SessionLog::create(['session_id'=>$s->id,'action'=>'opened','performed_by'=>$user->id]);
        return response()->json(['status'=>'success','session'=>$s]);
    }

    // Close session for current user
    public function close(Request $request)
    {
        $user = Auth::user();
        if(!$user) return response()->json(['errors'=>'Unauthorized'], 401);
        $s = DaySession::where('user_id',$user->id)->whereNull('closed_at')->first();
        if(!$s) return response()->json(['status'=>'error','message'=>'Aucune session ouverte'], 422);
        $s->closed_at = Carbon::now();
        $s->closed_by = $user->id;
        $s->save();
        SessionLog::create(['session_id'=>$s->id,'action'=>'closed','performed_by'=>$user->id]);
        return response()->json(['status'=>'success']);
    }

    // Admin close session for a user
    public function adminClose(Request $request)
    {
        $user = Auth::user();
        if(!$user || !$user->hasRole('admin')) return response()->json(['errors'=>'Unauthorized'], 401);
        $v = Validator::make($request->all(), ['session_id'=>'required|integer','reason'=>'nullable|string']);
        if($v->fails()) return response()->json(['errors'=>$v->errors()], 422);
        $s = DaySession::find($request->session_id);
        if(!$s) return response()->json(['errors'=>'Session introuvable'], 404);
        if($s->closed_at) return response()->json(['status'=>'error','message'=>'Session déjà fermée'], 422);
        $s->closed_at = Carbon::now();
        $s->closed_by = $user->id;
        $s->save();
        SessionLog::create(['session_id'=>$s->id,'action'=>'admin_closed','performed_by'=>$user->id,'reason'=>$request->reason]);
        return response()->json(['status'=>'success']);
    }

    // Return session status and shift timers for current user
    public function status(Request $request)
    {
        $user = Auth::user();
        if(!$user) return response()->json(['errors'=>'Unauthorized'], 401);

        $now = Carbon::now();
        $empShift = EmployeeShift::where('employee_id',$user->id)->latest()->first();
        $session = DaySession::where('user_id',$user->id)->whereNull('closed_at')->latest()->first();

        $data = ['has_session'=> (bool)$session, 'session'=>$session];

        if($empShift && $empShift->pattern){
            $pattern = $empShift->pattern;
            $dateDebut = Carbon::parse($empShift->date_debut);
            $startTime = $pattern->start_time ?: '00:00:00';
            $dateDebutTime = Carbon::parse($empShift->date_debut . ' ' . $startTime);
            // compute days elapsed based on timestamp anchored at date_debutTime
            $secondsElapsed = $dateDebutTime->diffInSeconds($now);
            $daysElapsed = intdiv(max(0, $secondsElapsed), 24*60*60);
            $cycle = max(1, ($pattern->jours_travail ?:1) + ($pattern->jours_repos ?:0));
            $pos = $daysElapsed % $cycle;
            $isOnToday = $pos < ($pattern->jours_travail ?:1) || $empShift->everyday==1 || $empShift->everyday==='1';

            // compute current shift start anchored to dateDebutTime + daysElapsed
            $shiftStart = (clone $dateDebutTime)->addDays($daysElapsed);
            $shiftDuration = (int)env('SHIFT_DURATION_HOURS',24);
            $shiftEnd = (clone $shiftStart)->addHours($shiftDuration);

            $data['is_on'] = $isOnToday;
            $data['shift_start'] = $shiftStart->toDateTimeString();
            $data['shift_end'] = $shiftEnd->toDateTimeString();
            $data['now'] = $now->toDateTimeString();
            $data['seconds_to_end'] = max(0, $now->diffInRealSeconds($shiftEnd));

            // grace window: 10 minutes after shift end when session still open
            if($session && $now->gt($shiftEnd)){
                $graceEnds = (clone $shiftEnd)->addMinutes(10);
                $data['in_grace'] = $now->lte($graceEnds);
                $data['grace_seconds_left'] = max(0, $now->diffInRealSeconds($graceEnds));
            }
        }

        return response()->json($data);
    }
}
