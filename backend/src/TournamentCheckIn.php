<?php

/** Arrival on a confirmed entry. The entry state stays confirmed. Times are Asia/Kolkata. */
final class TournamentCheckIn
{
    public const EARLY_MINUTES = 30;

    /** @return array{ok:bool,message:string} */
    public static function decide(string $state, ?string $checkedInAt, ?string $start, ?string $end, string $now): array
    {
        if ($state !== 'confirmed') {
            return ['ok' => false, 'message' => 'Only a confirmed entry can be checked in.'];
        }
        if ($checkedInAt !== null && $checkedInAt !== '') {
            return ['ok' => false, 'message' => 'This entry is already checked in.'];
        }
        $hasStart = $start !== null && $start !== '';
        $hasEnd = $end !== null && $end !== '';
        if ($hasStart !== $hasEnd) {
            return ['ok' => false, 'message' => 'The event needs a start and end before check-in.'];
        }
        if ($hasStart && $hasEnd) {
            $zone = new DateTimeZone('Asia/Kolkata');
            $startAt = new DateTimeImmutable($start, $zone);
            $endAt = new DateTimeImmutable($end, $zone);
            $nowAt = new DateTimeImmutable($now, $zone);
            if ($nowAt < $startAt->modify('-' . self::EARLY_MINUTES . ' minutes')) {
                return ['ok' => false, 'message' => 'Check-in opens 30 minutes before the event starts.'];
            }
            if ($nowAt >= $endAt) {
                return ['ok' => false, 'message' => 'Check-in closes when the event ends.'];
            }
        }
        return ['ok' => true, 'message' => 'Checked in.'];
    }

    public static function code(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $size = strlen($alphabet);
        $raw = random_bytes(8);
        $code = '';
        for ($i = 0; $i < 8; $i++) {
            $code .= $alphabet[ord($raw[$i]) % $size];
        }
        return $code;
    }

    public static function codeValue(mixed $value): string|false
    {
        $value = strtoupper(trim((string)$value));
        if (!preg_match('/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/', $value)) {
            return false;
        }
        return $value;
    }
}
