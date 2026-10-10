<?php

namespace App\Http\Controllers\emplacement;

use App\Models\Emplacement;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;

class EmplacementController extends Controller
{
    public function delete($id)
{
    $emplacement = Emplacement::find($id);

    if (!$emplacement) {
        return response()->json([
            'status' => 'error',
            'message' => 'Emplacement introuvable.',
        ]);
    }

    $emplacement->delete();

    return response()->json([
        'status' => 'success',
        'result' => $emplacement,
        'message' => 'Emplacement supprimé avec succès !',
    ]);
}
}
