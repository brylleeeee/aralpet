<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['source_type', 'source_id', 'amount', 'earned_on'])]
class XpLedger extends Model
{
    protected $table = 'xp_ledger';

    protected function casts(): array
    {
        return [
            'earned_on' => 'date',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}