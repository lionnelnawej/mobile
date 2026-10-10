<?php

namespace App\Http\Controllers;

use App\Models\LiaisonData;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;

class SettingController extends Controller
{
    public function sendLinkRequest(Request $request)
    {
        $data = $request->validate([
            'code_societe'                => 'required|string',
        ]);

        $user = Auth::user();
        $url = 'https://hvdhbiwzfkssmnftbpvs.supabase.co/functions/v1/liaison-request';

        $data["code_etablissement"] = $user->etablissement->token;
        $data["nom_etablissement"] = $user->etablissement->nom;
        $data["type_etablissement"] = $user->etablissement->type;
        $data["administrateur_etablissement"] = $user->name;
        $data["phone_etablissement"] = $user->etablissement->telephone ?? "";

        try {
            $response = Http::post($url, $data);

            if($response->successful()){
                $res = $response->json();
                LiaisonData::updateOrCreate(["code_cpte"=>$data["code_societe"],],[
                    "code_cpte"=>$data["code_societe"], 
                    "token"=> $user->etablissement->token, 
                    "liaison_id" => $res["liaison_id"], 
                    "ets_id" => $user->ets_id
                ]);
            }
            return response()->json([
                'success' => $response->successful(),
                'data'    => $response->json(),
                'status'  => $response->status()
            ]);

        }
        catch (\Illuminate\Validation\ValidationException $e) {
            $errors = $e->validator->errors()->all();
            return response()->json(['errors' => $errors]);
        } 
        catch (\Throwable $e) {
            return response()->json([
                "errors"=>$e->getMessage()
            ]);
        }

    }

    public function checkLink(Request $request)
    {
        $user = Auth::user();
        $url = 'https://hvdhbiwzfkssmnftbpvs.supabase.co/functions/v1/check-liaison-status';

        $liaisonId = $user->etablissement->liaison->liaison_id;
        $data = [
            "liaison_id" => $liaisonId
        ];

        try {
            $response = Http::post($url, $data);

            if($response->successful()){
                $res = $response->json();
                if($res["statut"] === 0){
                    $liaison = LiaisonData::where("liaison_id", $liaisonId)->first();
                    $liaison->update([
                        "status"=>"success"
                    ]);
                }
            }
            return response()->json([
                'success' => $response->successful(),
                'data'    => $response->json(),
                'status'  => $response->status()
            ]);

        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage()
            ], 500);
        }
    }

}
