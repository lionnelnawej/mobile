<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class Chambre extends Model
{
    use HasFactory;

    protected $primaryKey = 'id';

    protected $fillable = [
        "numero",
        "type",
        "capacite",
        "prix",
        "prix_devise",
        "emplacement_id",
        "statut",
        "ets_id"
    ];

    protected $casts = [
        'date_debut' => 'date',
        'date_fin'   => 'date',
    ];

    public function reservations()
    {
        return $this->hasMany(Reservation::class, 'chambre_id');
    }

    /**
     * Détermine l'état de la chambre :
     * - Occupée : une réservation en cours aujourd'hui
     * - Réservée : une réservation future
     * - Libre : aucune réservation
     */
    /**
     * Statut dynamique en fonction des réservations.
     *
     * - occupée : si la date du jour est comprise dans une réservation confirmée
     * - réservée : si une réservation confirmée est prévue mais commence plus tard
     * - libre : sinon
     */
    /* public function getStatutAttribute(): string
    {
        $today = Carbon::today();

        $reservation = $this->reservations()
            ->where('statut', 'confirmée')
            ->where(function ($q) use ($today) {
                $q->whereBetween('date_debut', [$today, $today])
                  ->orWhereBetween('date_fin', [$today, $today])
                  ->orWhere('date_debut', '>', $today);
            })
            ->orderBy('date_debut')
            ->first();

        if ($reservation) {
            // Si pour une raison quelconque le cast n'a pas fonctionné
            $dateDebut = $reservation->date_debut instanceof Carbon
                ? $reservation->date_debut
                : Carbon::parse($reservation->date_debut);

            $dateFin = $reservation->date_fin instanceof Carbon
                ? $reservation->date_fin
                : Carbon::parse($reservation->date_fin);

            if ($dateDebut->lte($today) && $dateFin->gte($today)) {
                return 'occupée';
            }

            if ($dateDebut->gt($today)) {
                return 'réservée';
            }
        }

        return 'libre';
    }
 */

    public function emplacement(){
        return $this->belongsTo(Emplacement::class, "emplacement_id");
    }

   
}
