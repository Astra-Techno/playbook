<?php

/**
 * Open spots on a booking pass, posted to Matches as a match request linked to
 * the booking (match_requests.booking_id). Whoever joins is added to the squad.
 */
final class SquadMatch
{
    /**
     * Match request fields for a booking, or why it can't be posted.
     * @param array{id:int|string,user_id:int|string,court_id:int|string,status:string,start_time:string,end_time:string,court_name?:string,court_type?:string}|null $booking
     * @return array{ok:true,fields:array<string,mixed>}|array{ok:false,http:int,message:string}
     */
    public static function fromBooking(?array $booking, int $callerId, int $spots, string $now): array
    {
        if (!$booking) return ['ok' => false, 'http' => 404, 'message' => 'Booking not found'];
        if ((int)$booking['user_id'] !== $callerId) return ['ok' => false, 'http' => 403, 'message' => 'Only the person who booked can look for players'];
        if (($booking['status'] ?? '') !== 'confirmed') return ['ok' => false, 'http' => 409, 'message' => 'This booking is not active'];
        if ($booking['start_time'] <= $now) return ['ok' => false, 'http' => 409, 'message' => 'This game has already started'];
        if ($spots < 1 || $spots > 20) return ['ok' => false, 'http' => 422, 'message' => 'Ask for 1 to 20 players'];
        $court = trim((string)($booking['court_name'] ?? ''));
        return ['ok' => true, 'fields' => [
            'booking_id' => (int)$booking['id'],
            'court_id' => (int)$booking['court_id'],
            'title' => $court === '' ? "Need $spots" : "Need $spots at $court",
            'sport' => ($booking['court_type'] ?? '') === '' ? null : (string)$booking['court_type'],
            'date' => substr($booking['start_time'], 0, 10),
            'start_time' => substr($booking['start_time'], 11, 8),
            'end_time' => substr($booking['end_time'], 11, 8),
            'players_needed' => $spots,
        ]];
    }
}
