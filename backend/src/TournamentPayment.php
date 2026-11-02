<?php

/** What a successful entry payment does to a pending registration. */
final class TournamentPayment
{
    /**
     * @return array{ok:bool,message?:string,state?:string,hold?:string,refund?:bool}
     */
    public static function decide(
        string $registrationState,
        int $captainUserId,
        int $paymentUserId,
        float $fee,
        float $paidAmount,
        ?string $holdState,
        ?string $holdExpires,
        string $now,
        int $capacity,
        int $otherSeatsTaken,
        bool $needsApproval = false
    ): array {
        if ($captainUserId !== $paymentUserId) {
            return ['ok' => false, 'refund' => true, 'message' => 'This payment does not belong to the entry.'];
        }
        if (self::paise($fee) !== self::paise($paidAmount) || self::paise($fee) <= 0) {
            return ['ok' => false, 'refund' => true, 'message' => 'The payment does not match the entry fee.'];
        }
        if ($registrationState === 'confirmed') {
            return ['ok' => true, 'state' => 'confirmed', 'hold' => 'unchanged'];
        }
        if ($registrationState !== 'pending') {
            return ['ok' => false, 'refund' => true, 'message' => 'This entry cannot be confirmed.'];
        }
        $held = $holdState === 'active' && $holdExpires !== null && $holdExpires > $now;
        $open = $capacity === 0 || $otherSeatsTaken < $capacity;
        if ($held || $open) {
            return [
                'ok' => true,
                'state' => $needsApproval ? 'pending_approval' : 'confirmed',
                'hold' => 'consumed',
            ];
        }
        return ['ok' => false, 'refund' => true, 'message' => 'The seat was released before payment.'];
    }

    public static function paise(float $amount): int
    {
        return (int)round($amount * 100);
    }
}
