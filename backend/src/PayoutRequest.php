<?php

/** An owner can ask for a manual transfer. The request is not a payout. */
class PayoutRequest
{
    public static function plan(float $available, float $amount, bool $openExists, string $note): array
    {
        $note = trim($note);
        if ($openExists) {
            return ['ok' => false, 'message' => 'A payout request is already open'];
        }
        $amount = round($amount, 2);
        $available = round($available, 2);
        if ($amount <= 0) {
            return ['ok' => false, 'message' => 'Enter an amount greater than zero'];
        }
        if ($amount > $available) {
            return ['ok' => false, 'message' => 'Amount is above what has not yet been paid out'];
        }
        if (strlen($note) > 200) {
            return ['ok' => false, 'message' => 'Note is too long'];
        }
        return ['ok' => true, 'amount' => $amount, 'note' => $note];
    }
}
