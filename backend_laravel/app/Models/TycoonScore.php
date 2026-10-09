<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Meilleur score Maintelio Tycoon d'un appareil pour un rôle.
 */
class TycoonScore extends Model
{
    protected $fillable = [
        'device_id',
        'role',
        'pseudo',
        'score',
    ];

    protected $hidden = [
        'device_id',
    ];

    protected function casts(): array
    {
        return [
            'score' => 'integer',
        ];
    }
}
