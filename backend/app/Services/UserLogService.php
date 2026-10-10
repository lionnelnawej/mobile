<?php
namespace App\Services;

use App\Models\SaleDay;
use App\Models\UserLog;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;


class UserLogService{
    public function storeLog(Request $request){
        $user = Auth::user();
        $now = Carbon::now()->setTimezone("Africa/Kinshasa");

        // Récupération du log du jour (s'il existe déjà)
        $log = UserLog::where("user_id", $user->id)
            ->where("log_date", $now->toDateString())
            ->first();

        // Jour de vente actif
        $saleDay = SaleDay::whereNull("end_time")->where("ets_id", $user->ets_id)->latest()->first();

        $route = $request->route()->getName();

        if (!$log) {
            $log = UserLog::create([
                "user_id"      => $user->id,
                "sale_day_id"  => $saleDay->id ?? null,
                "log_date"     => $now->toDateString(),
                "logged_in_at" => $now,
                "ets_id"       => $user->ets_id,
                "status"       => "online",
            ]);
        } else {
            // 👉 Si logout → on met à jour le log existant
            if ($route === "logout") {
                $log->update([
                    "logged_out_at" => $now,
                    "status"        => "offline",
                ]);
            } else {
                // Si l'user se reconnecte dans la même journée
                $log->update([
                    "status" => "online",
                ]);
            }
        }
        return $log;
    }
}
