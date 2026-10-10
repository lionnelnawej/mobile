<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\EmployeeShift;
use App\Models\OverrideShift;
use App\Models\Absence;
use App\Models\DaySession;
use App\Models\SessionLog;
use Carbon\Carbon;

class CheckShiftAccess
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        if (!Auth::check()) {
            return $next($request);
        }

        $user = Auth::user();

        // Admin bypass
        if ($user->hasRole('admin')) {
            return $next($request);
        }

        $today = Carbon::today();
        $now = Carbon::now();

        // Override for today
        $override = OverrideShift::where('user_id', $user->id)->where('date', $today->toDateString())->where('autorise', true)->first();
        if ($override) {
            return $next($request);
        }

        // Absence check
        $absence = Absence::where('user_id', $user->id)->where('date', $today->toDateString())->first();
        if ($absence) {
            return $this->deny($request, "Vous êtes en absence aujourd'hui");
        }

        $empShift = EmployeeShift::where('employee_id', $user->id)->latest()->first();
        if (!$empShift) {
            // No assignment -> allow by default
            return $next($request);
        }

        $pattern = $empShift->pattern;
        if (!$pattern) {
            return $next($request);
        }

        // compute days elapsed based on timestamp anchored at date_debut + pattern.start_time
        $startTime = $pattern->start_time ?: '00:00:00';
        $dateDebutTime = Carbon::parse($empShift->date_debut . ' ' . $startTime);
        $secondsElapsed = $dateDebutTime->diffInSeconds($now);
        $joursEcoules = intdiv(max(0, $secondsElapsed), 24*60*60);
        $cycle = max(1, ($pattern->jours_travail ?? 1) + ($pattern->jours_repos ?? 0));
        $position = $joursEcoules % $cycle;

        $isOnToday = ($position < ($pattern->jours_travail ?? 1)) || ($empShift->everyday == 1 || $empShift->everyday === '1');
        if (!$isOnToday) {
            return $this->deny($request, "Vous n'êtes pas programmé aujourd'hui");
        }

        // compute the current shift start by anchoring to date_debut + start_time and adding joursEcoules days
        $shiftStart = (clone $dateDebutTime)->addDays($joursEcoules);
        $shiftDuration = (int) env('SHIFT_DURATION_HOURS', 24);
        $shiftEnd = (clone $shiftStart)->addHours($shiftDuration);

        // Time tolerance check: allow access during entire shift (shiftStart -> shiftEnd)
        // tolerance_before/after extend the allowed window around the shift boundaries
        if ($pattern->start_time) {
            $allowedStart = (clone $shiftStart)->subMinutes($pattern->tolerance_before ?? 30);
            $allowedEnd = (clone $shiftEnd)->addMinutes($pattern->tolerance_after ?? 120);
            if (!($now->between($allowedStart, $allowedEnd))) {
                // compute time until next possible allowed start (next shiftStart minus tolerance_before)
                if ($now->lt($allowedStart)) {
                    $retrySeconds = $now->diffInSeconds($allowedStart);
                } else {
                    // after allowed end: estimate next ON shift by advancing by cycle days until an ON day
                    $nextShiftStart = (clone $dateDebutTime)->addDays($joursEcoules + 1);
                    // advance until we find an ON day
                    $maxIter = $cycle * 2;
                    $found = false;
                    for ($i = 0; $i < $maxIter; $i++) {
                        $candidateN = $joursEcoules + 1 + $i;
                        $posN = $candidateN % $cycle;
                        if ($posN < ($pattern->jours_travail ?? 1)) { // ON
                            $nextShiftStart = (clone $dateDebutTime)->addDays($candidateN);
                            $found = true;
                            break;
                        }
                    }
                    if (!$found) {
                        $nextShiftStart = (clone $dateDebutTime)->addDays($joursEcoules + 1);
                    }
                    $nextAllowed = (clone $nextShiftStart)->subMinutes($pattern->tolerance_before ?? 30);
                    $retrySeconds = $now->diffInSeconds($nextAllowed);
                }
                return $this->deny($request, "En dehors de la fenêtre de tolérance pour votre shift", $retrySeconds);
            }
        }

        // session-related checks
        $openSession = DaySession::where('user_id', $user->id)->whereNull('closed_at')->latest()->first();

        // If within last 2 hours of shift, set warning header
        $shiftWarningSeconds = null;
        if ($now->lte($shiftEnd) && $now->gte((clone $shiftEnd)->subHours(2))) {
            $shiftWarningSeconds = $now->diffInSeconds($shiftEnd);
        }

        // If after shift end
        if ($now->gt($shiftEnd)) {
            if ($openSession) {
                // allow 10 minute grace period to close
                $graceEnds = (clone $shiftEnd)->addMinutes(10);
                if ($now->lte($graceEnds)) {
                    $graceSeconds = $now->diffInSeconds($graceEnds);
                    $response = $next($request);
                    if ($shiftWarningSeconds) $response->headers->set('X-Shift-Warning', $shiftWarningSeconds);
                    $response->headers->set('X-Shift-Grace', $graceSeconds);
                    return $response;
                } else {
                    // grace expired: auto-close session on server side and log
                    try{
                        $openSession->closed_at = Carbon::now();
                        $openSession->closed_by = null;
                        $openSession->save();
                        SessionLog::create(['session_id'=>$openSession->id,'action'=>'auto_closed','performed_by'=>null,'reason'=>'Grace period expired']);
                    } catch (\Throwable $e) {
                        // ignore logging errors
                    }
                    return $this->deny($request, "Temps de clôture expiré. Contactez l'administrateur.");
                }
            }
            // no open session and after shift -> deny
            return $this->deny($request, "Vous êtes en repos. Vous ne pouvez pas effectuer d'action. Reposez-vous ! Bon repos.");
        }

        $response = $next($request);
        if ($shiftWarningSeconds) {
            $response->headers->set('X-Shift-Warning', $shiftWarningSeconds);
        }
        return $response;
    }

    protected function deny(Request $request, $message, $retrySeconds = null)
    {
        if ($request->expectsJson() || $request->is('api/*')) {
            $payload = ['errors' => $message];
            if (!is_null($retrySeconds)) $payload['retry_in_seconds'] = $retrySeconds;
            return response()->json($payload, 403);
        }
        $data = ['message' => $message];
        if (!is_null($retrySeconds)) $data['retry_in_seconds'] = $retrySeconds;
        return response()->view('shift_blocked', $data, 403);
    }
}
