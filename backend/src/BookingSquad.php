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

    /** Booking row joined to its venue owner, or null. */
    public static function booking(PDO $db, int $bookingId): ?array
    {
        $stmt = $db->prepare('SELECT b.id, b.user_id, b.court_id, c.owner_id FROM bookings b JOIN courts c ON c.id = b.court_id WHERE b.id = ?');
        $stmt->execute([$bookingId]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }
}
