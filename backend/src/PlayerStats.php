<?php

/**
 * Player card stats from the games PlayerCrew::load returns.
 * Attendance is recorded per booking, so every player on a booking shares its check-in.
 */
final class PlayerStats
{
    /**
     * @param list<array{start_time:string,end_time:string,attendance?:?string,court_type?:?string}> $bookings
     * @return array{hours:float, games:int, show_up_rate:?int, marked:int, sports:list<string>}
     */
    public static function compute(array $bookings, string $now): array
    {
        $seconds = 0;
        $games = 0;
        $showed = 0;
        $marked = 0;
        $sports = [];
        foreach ($bookings as $b) {
            if ($b['end_time'] > $now) continue; // only games already played
            $games++;
            $seconds += max(0, strtotime($b['end_time']) - strtotime($b['start_time']));
            $att = $b['attendance'] ?? null;
            if ($att === 'checked_in' || $att === 'no_show') {
                $marked++;
                if ($att === 'checked_in') $showed++;
            }
            $type = trim((string)($b['court_type'] ?? ''));
            if ($type !== '') $sports[$type] = ($sports[$type] ?? 0) + 1;
        }
        arsort($sports);
        return [
            'hours' => round($seconds / 3600, 1),
            'games' => $games,
            // Shown only once a venue has marked at least one game.
            'show_up_rate' => $marked > 0 ? (int)round(100 * $showed / $marked) : null,
            'marked' => $marked,
            'sports' => array_slice(array_keys($sports), 0, 3),
        ];
    }
}
