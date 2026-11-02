<?php

/**
 * Today's booked time against a venue's open window.
 * Confirmed bookings only. Closures are not included.
 * A venue with spaces uses open minutes once per space.
 * A booking with no space does not fill a space.
 * Overlapping bookings are added, so a shared hour can pass 100%.
 */
class OccupancyMath
{
    /** @return array{0:string,1:string} */
    public static function openWindow(string $day, string $open, string $close): array
    {
        $open = substr($open !== '' ? $open : '06:00:00', 0, 8);
        $close = substr($close !== '' ? $close : '22:00:00', 0, 8);
        $start = $day . ' ' . $open;
        if ($close > $open) {
            return [$start, $day . ' ' . $close];
        }
        $next = date('Y-m-d', strtotime($day . ' +1 day'));
        return [$start, $next . ' ' . $close];
    }

    public static function overlapMinutes(string $startA, string $endA, string $startB, string $endB): int
    {
        $a1 = strtotime($startA);
        $a2 = strtotime($endA);
        $b1 = strtotime($startB);
        $b2 = strtotime($endB);
        if ($a1 === false || $a2 === false || $b1 === false || $b2 === false || $a2 <= $a1 || $b2 <= $b1) {
            return 0;
        }
        $start = max($a1, $b1);
        $end = min($a2, $b2);
        if ($end <= $start) {
            return 0;
        }
        return (int)(($end - $start) / 60);
    }

    /**
     * @param list<array{start:string,end:string,status?:string,sub_court_id?:mixed}> $bookings
     * @return array{booked_minutes:int,open_minutes:int,confirmed_count:int}
     */
    public static function summarize(string $day, string $open, string $close, int $spaceCount, array $bookings): array
    {
        [$winStart, $winEnd] = self::openWindow($day, $open, $close);
        $span = self::overlapMinutes($winStart, $winEnd, $winStart, $winEnd);
        $units = $spaceCount > 0 ? $spaceCount : 1;
        $booked = 0;
        $count = 0;
        foreach ($bookings as $booking) {
            if (($booking['status'] ?? 'confirmed') !== 'confirmed') {
                continue;
            }
            $sub = $booking['sub_court_id'] ?? null;
            $hasSpace = $sub !== null && $sub !== '' && (int)$sub > 0;
            if ($spaceCount > 0 && !$hasSpace) {
                continue;
            }
            $minutes = self::overlapMinutes((string)$booking['start'], (string)$booking['end'], $winStart, $winEnd);
            if ($minutes <= 0) {
                continue;
            }
            $booked += $minutes;
            $count++;
        }
        return [
            'booked_minutes' => $booked,
            'open_minutes' => $span * $units,
            'confirmed_count' => $count,
        ];
    }
}
