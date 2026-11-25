<?php

require_once __DIR__ . '/TournamentCheckIn.php';

/**
 * QR check-in for court bookings. The pass shows "KOCOURT-CHECKIN:<booking id>:<code>",
 * where code is a random 8-character door code stored on the booking (never derived).
 */
final class BookingCheckIn
{
    public const PREFIX = 'KOCOURT-CHECKIN';

    public static function payload(int $bookingId, string $code): string
    {
        return self::PREFIX . ':' . $bookingId . ':' . $code;
    }

    /** @return array{id:int,code:string}|null */
    public static function parse(string $payload): ?array
    {
        $parts = explode(':', trim($payload));
        if (count($parts) !== 3 || $parts[0] !== self::PREFIX || !ctype_digit($parts[1]) || (int)$parts[1] <= 0) {
            return null;
        }
        $code = TournamentCheckIn::codeValue($parts[2]);
        return $code === false ? null : ['id' => (int)$parts[1], 'code' => $code];
    }

    /** Stored code matches the scanned one, in constant time. */
    public static function matches(?string $stored, string $scanned): bool
    {
        return $stored !== null && $stored !== '' && hash_equals($stored, $scanned);
    }

    /** The booker and players added to the squad may show the pass. */
    public static function canShow(int $bookerId, int $userId, bool $isSquadPlayer): bool
    {
        return $bookerId === $userId || $isSquadPlayer;
    }

    /** Existing code, or a new unique one saved on the booking. */
    public static function ensureCode(PDO $db, int $bookingId, ?string $current): string
    {
        if ($current !== null && $current !== '') {
            return $current;
        }
        $save = $db->prepare('UPDATE bookings SET check_in_code = ? WHERE id = ? AND check_in_code IS NULL');
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $code = TournamentCheckIn::code();
            try {
                $save->execute([$code, $bookingId]);
            } catch (PDOException $e) {
                continue; // unique collision; draw again
            }
            break;
        }
        // Another request may have set it first; the stored value wins.
        $read = $db->prepare('SELECT check_in_code FROM bookings WHERE id = ?');
        $read->execute([$bookingId]);
        $stored = (string)$read->fetchColumn();
        if ($stored === '') {
            throw new RuntimeException('Could not create a check-in code.');
        }
        return $stored;
    }
}
