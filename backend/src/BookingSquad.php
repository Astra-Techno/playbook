<?php

/** Who may see or grow a booking's squad (booking_players). */
class BookingSquad
{
    /**
     * Booking facts plus the caller's relationship to it.
     * @param array{user_id:int|string, owner_id:int|string} $booking
     */
    public static function canView(array $booking, int $userId, string $role, bool $isPlayer, bool $isStaff): bool
    {
        return $role === 'admin'
            || (int)$booking['user_id'] === $userId
            || (int)$booking['owner_id'] === $userId
            || $isPlayer
            || $isStaff;
    }

    /** Only the person who booked (or an admin) can add players; each add notifies them. */
    public static function canInvite(array $booking, int $userId, string $role): bool
    {
        return $role === 'admin' || (int)$booking['user_id'] === $userId;
    }

    /** Each player's share, rounded up: the booker plus $squadSize squad mates split the total. */
    public static function share(float $total, int $squadSize): ?int
    {
        if ($total <= 0) return null;
        return (int)ceil($total / max(1, $squadSize + 1));
    }

    /**
     * In-app reminder for a squad mate who has not paid the booker back yet.
     * @return array{title:string, body:string}
     */
    public static function reminder(string $bookerName, string $courtName, string $startTime, ?int $share): array
    {
        $when = date('D j M, g A', strtotime($startTime));
        $first = trim(explode(' ', trim($bookerName))[0] ?? '') ?: 'Your booker';
        return [
            'title' => $share ? "$first is waiting for your ₹$share" : "$first is waiting for your share",
            'body' => "For the game at $courtName on $when. Pay them directly; they'll mark it paid.",
        ];
    }

    /** Booking row joined to its venue owner, or null. */
    public static function booking(PDO $db, int $bookingId): ?array
    {
        $stmt = $db->prepare('SELECT b.id, b.user_id, b.court_id, c.owner_id FROM bookings b JOIN courts c ON c.id = b.court_id WHERE b.id = ?');
        $stmt->execute([$bookingId]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }
}
