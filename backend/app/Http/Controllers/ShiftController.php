<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ShiftPattern;
use App\Models\EmployeeShift;
use App\Models\OverrideShift;
use App\Models\Absence;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;

class ShiftController extends Controller
{
    public function index()
    {
        return view('shifts');
    }

    public function list()
    {
        $ets = Auth::user()->ets_id ?? null;
        $patterns = ShiftPattern::where('ets_id', $ets)->get();
        // users eligible for assignment (serveur, caissier)
        $users = User::where('ets_id', $ets)->whereIn('role', ['serveur', 'caissier'])->get();
        // all users (for override/absence selects)
        $allUsers = User::where('ets_id', $ets)->get();
        $assignments = EmployeeShift::with('pattern', 'user')->where('ets_id', $ets)->get();
        $overrides = \App\Models\OverrideShift::with(['user','autorisePar'])->whereIn('user_id', $allUsers->pluck('id')->toArray())->where('autorise', true)->where('date', '>=', now()->subMonths(3)->toDateString())->get();
        $absences = \App\Models\Absence::with('user')->whereIn('user_id', $allUsers->pluck('id')->toArray())->where('date', '>=', now()->subMonths(3)->toDateString())->get();

        return response()->json(["patterns" => $patterns, "assignments" => $assignments, 'users' => $users, 'allUsers' => $allUsers, 'overrides' => $overrides, 'absences' => $absences]);
    }

    public function storePattern(Request $request)
    {
        $data = $request->validate([
            'nom' => 'required|string',
            'jours_travail' => 'required|int|min:1',
            'jours_repos' => 'required|int|min:0',
            'start_time' => 'nullable',
            'tolerance_before' => 'nullable|int',
            'tolerance_after' => 'nullable|int'
        ]);

        $data['ets_id'] = Auth::user()->ets_id ?? null;

        $pattern = ShiftPattern::create($data);
        return response()->json(['status' => 'success', 'pattern' => $pattern]);
    }

    public function assignEmployee(Request $request)
    {
        $ets = Auth::user()->ets_id ?? null;

        // allow an "everyday" option which creates/uses a pattern with jours_repos = 0
        $everyday = $request->boolean('everyday');

        if ($everyday) {
            $pattern = ShiftPattern::firstOrCreate(
                ['ets_id' => $ets, 'jours_travail' => 1, 'jours_repos' => 0],
                ['nom' => 'TOUS_LES_JOURS', 'start_time' => null, 'tolerance_before' => 30, 'tolerance_after' => 120]
            );
            $shift_pattern_id = $pattern->id;
        } else {
            $request->validate([
                'shift_pattern_id' => 'required|exists:shift_patterns,id',
            ]);
            $shift_pattern_id = $request->shift_pattern_id;
        }

        $data = $request->validate([
            'employee_id' => 'required|exists:users,id',
            'date_debut' => 'required|date'
        ]);

        // prevent multiple assignments per user in same ets
        $exists = EmployeeShift::where('employee_id', $data['employee_id'])->where('ets_id', $ets)->exists();
        if ($exists) {
            return response()->json(['status' => 'error', 'message' => 'L\'utilisateur a déjà une affectation'], 422);
        }

        // ensure employee belongs to same ets
        $employee = User::find($data['employee_id']);
        if ($employee && $employee->ets_id != $ets) {
            return response()->json(['status' => 'error', 'message' => "L'utilisateur n'appartient pas à cet établissement"], 422);
        }

        $assign = EmployeeShift::create([
            'employee_id' => $data['employee_id'],
            'shift_pattern_id' => $shift_pattern_id,
            'date_debut' => $data['date_debut'],
            'ets_id' => $ets
        ]);

        return response()->json(['status' => 'success', 'assign' => $assign]);
    }

    public function deleteAssignment(Request $request)
    {
        $id = $request->input('id');
        $assign = EmployeeShift::find($id);
        if (!$assign) return response()->json(['status' => 'error', 'message' => 'Affectation introuvable'], 404);
        // permission and ets check
        $ets = Auth::user()->ets_id ?? null;
        if ($assign->ets_id && $assign->ets_id != $ets) {
            return response()->json(['status' => 'error', 'message' => 'Non autorisé'], 403);
        }
        $assign->delete();
        return response()->json(['status' => 'success']);
    }

    public function deleteOverride(Request $request)
    {
        $id = $request->input('id');
        $ov = \App\Models\OverrideShift::find($id);
        if (!$ov) return response()->json(['status' => 'error', 'message' => 'Override introuvable'], 404);
        $ets = Auth::user()->ets_id ?? null;
        if ($ov->user && $ov->user->ets_id && $ov->user->ets_id != $ets) {
            return response()->json(['status' => 'error', 'message' => 'Non autorisé'], 403);
        }
        $ov->delete();
        return response()->json(['status' => 'success']);
    }

    public function deleteAbsence(Request $request)
    {
        $id = $request->input('id');
        $ab = \App\Models\Absence::find($id);
        if (!$ab) return response()->json(['status' => 'error', 'message' => 'Absence introuvable'], 404);
        $ets = Auth::user()->ets_id ?? null;
        if ($ab->user && $ab->user->ets_id && $ab->user->ets_id != $ets) {
            return response()->json(['status' => 'error', 'message' => 'Non autorisé'], 403);
        }
        $ab->delete();
        return response()->json(['status' => 'success']);
    }

    public function createOverride(Request $request)
    {
        $data = $request->validate([
            'user_id' => 'required|exists:users,id',
            'date' => 'required|date',
            'raison' => 'nullable|string'
        ]);
        $ets = Auth::user()->ets_id ?? null;

        // Check that the user is NOT scheduled on that date (override is only for users who are off that day)
        $targetUser = User::find($data['user_id']);
        $empShift = EmployeeShift::where('employee_id', $targetUser->id)->where('ets_id', $ets)->latest()->first();
        // Build a datetime in the middle of the requested day to test whether that day is within an ON-period
        $requestedDateTime = Carbon::parse($data['date'])->setTime(12,0,0);

        if ($empShift && $empShift->date_debut) {
            $pattern = $empShift->pattern;
            if ($pattern) {
                $startTime = $pattern->start_time ?: '00:00:00';
                $dateDebutTime = Carbon::parse($empShift->date_debut . ' ' . $startTime);

                // if requested datetime is before the assignment start, user is not scheduled -> allow override
                if ($requestedDateTime->lt($dateDebutTime)) {
                    // allow
                } else {
                    $seconds = $dateDebutTime->diffInSeconds($requestedDateTime);
                    $joursEcoules = intdiv($seconds, 24*60*60);
                    $cycle = max(1, ($pattern->jours_travail ?? 1) + ($pattern->jours_repos ?? 0));
                    $position = $joursEcoules % $cycle;
                    if ($position < ($pattern->jours_travail ?? 1) || ($empShift->everyday == 1 || $empShift->everyday === '1')) {
                        return response()->json(['status' => 'error', 'message' => "Impossible d'autoriser : l'utilisateur est déjà programmé ce jour"], 422);
                    }
                }
            }
        }

        $data['autorise_par'] = Auth::id();
        $ov = OverrideShift::create($data);
        return response()->json(['status' => 'success', 'override' => $ov]);
    }

    public function createAbsence(Request $request)
    {
        $data = $request->validate([
            'user_id' => 'required|exists:users,id',
            'date' => 'required|date',
            'type' => 'nullable|string',
            'raison' => 'nullable|string'
        ]);

        $ab = Absence::create($data);
        return response()->json(['status' => 'success', 'absence' => $ab]);
    }
}
