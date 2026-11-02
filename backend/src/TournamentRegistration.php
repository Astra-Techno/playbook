<?php

/** A player's entry into one category. An unpaid entry keeps a seat only while its hold is active. */
final class TournamentRegistration
{
    public const HOLD_MINUTES = 10;

    public static function idempotencyKey(mixed $value): string|false
    {
        $value = trim((string)$value);
        if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $value)) {
            return false;
        }
        return $value;
    }

    public static function expiresAt(string $now): string
    {
        $zone = new DateTimeZone('Asia/Kolkata');
        return (new DateTimeImmutable($now, $zone))->modify('+' . self::HOLD_MINUTES . ' minutes')->format('Y-m-d H:i:s');
    }

    public static function countsAsSeat(string $state, ?string $holdState, ?string $holdExpires, string $now): bool
    {
        if ($state === 'confirmed' || $state === 'pending_approval') {
            return true;
        }
        if ($state !== 'pending') {
            return false;
        }
        return $holdState === 'active' && $holdExpires !== null && $holdExpires > $now;
    }

    /** @return array{ok:bool,message?:string,state?:string,hold?:bool} */
    public static function decide(int $capacity, int $seatsTaken, bool $waitlist, float $fee, bool $alreadyEntered, bool $approval = false): array
    {
        if ($alreadyEntered) {
            return ['ok' => false, 'message' => 'You are already entered in this category.'];
        }
        if ($capacity < 0 || $seatsTaken < 0 || $fee < 0) {
            return ['ok' => false, 'message' => 'This category cannot take entries.'];
        }
        $open = $capacity === 0 || $seatsTaken < $capacity;
        if (!$open && !$waitlist) {
            return ['ok' => false, 'message' => 'This category is full.'];
        }
        if (!$open) {
            return ['ok' => true, 'state' => 'waitlisted', 'hold' => false];
        }
        if ($fee > 0) {
            return ['ok' => true, 'state' => 'pending', 'hold' => true];
        }
        if ($approval) {
            return ['ok' => true, 'state' => 'pending_approval', 'hold' => false];
        }
        return ['ok' => true, 'state' => 'confirmed', 'hold' => false];
    }
}
