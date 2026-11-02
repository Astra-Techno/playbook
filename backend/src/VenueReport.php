<?php

/**
 * One venue's booking prices and collected payments stay separate.
 * Collected is passed in after successful refunds have been removed.
 * Owner payouts are not a venue figure.
 */
final class VenueReport
{
    public static function canView(bool $isAdmin, bool $isOwner): bool
    {
        return $isAdmin || $isOwner;
    }

    /**
     * @param list<array<string,mixed>> $bookings
     * @return array<string,int|float>
     */
    public static function build(array $bookings, float $collected): array
    {
        $confirmed = 0;
        $cancelled = 0;
        $gross = 0.0;
        $players = [];
        foreach ($bookings as $row) {
            $status = (string)($row['status'] ?? '');
            $userId = (int)($row['user_id'] ?? 0);
            if ($status === 'confirmed') {
                $confirmed++;
                $gross += (float)($row['total_price'] ?? 0);
                if ($userId > 0) {
                    $players[$userId] = ($players[$userId] ?? 0) + 1;
                }
            } elseif ($status === 'cancelled') {
                $cancelled++;
            }
        }
        $repeat = 0;
        foreach ($players as $count) {
            if ($count >= 2) {
                $repeat++;
            }
        }
        $decided = $confirmed + $cancelled;
        return [
            'confirmed_count' => $confirmed,
            'cancelled_count' => $cancelled,
            'booking_gross' => round($gross, 2),
            'collected' => round($collected, 2),
            'cancel_rate' => $decided > 0 ? round(100 * $cancelled / $decided, 1) : 0.0,
            'unique_players' => count($players),
            'repeat_players' => $repeat,
        ];
    }
}
