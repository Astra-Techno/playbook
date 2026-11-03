<?php

/** An owner alert for a confirmed booking that is due. A repeat uses the same event key. */
final class VenueAlert
{
    /**
     * @param list<array<string,mixed>> $bookings
     * @param list<string> $existingKeys
     * @return array{ok:bool,message?:string,alerts?:list<array{event_key:string,court_id:int,title:string,body:string}>}
     */
    public static function plan(array $bookings, array $existingKeys, string $now): array
    {
        $nowAt = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $now);
        $errors = DateTimeImmutable::getLastErrors();
        $badClock = is_array($errors) && (($errors['warning_count'] ?? 0) > 0 || ($errors['error_count'] ?? 0) > 0);
        if ($nowAt === false || $badClock) {
            return ['ok' => false, 'message' => 'The clock must be a date and time.'];
        }
        $until = $nowAt->modify('+60 minutes');
        $seenKeys = [];
        foreach ($existingKeys as $key) {
            $seenKeys[(string)$key] = true;
        }
        $alerts = [];
        $seenBookings = [];
        foreach ($bookings as $booking) {
            if (($booking['status'] ?? '') !== 'confirmed') {
                continue;
            }
            $attendance = $booking['attendance'] ?? null;
            if ($attendance !== null && $attendance !== '') {
                continue;
            }
            $id = (int)($booking['id'] ?? 0);
            $courtId = (int)($booking['court_id'] ?? 0);
            $start = (string)($booking['start_time'] ?? '');
            $end = (string)($booking['end_time'] ?? '');
            $startAt = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $start);
            $endAt = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $end);
            if ($id <= 0 || $courtId <= 0 || $startAt === false || $endAt === false) {
                continue;
            }
            if ($startAt > $until || $endAt <= $nowAt) {
                continue;
            }
            $eventKey = 'arrival:' . $id;
            if (isset($seenKeys[$eventKey]) || isset($seenBookings[$id])) {
                continue;
            }
            $seenKeys[$eventKey] = true;
            $seenBookings[$id] = true;
            $name = trim((string)($booking['guest_name'] ?? ''));
            if ($name === '') {
                $name = trim((string)($booking['player_name'] ?? ''));
            }
            if ($name === '') {
                $name = 'A player';
            }
            if (strlen($name) > 80) {
                $name = substr($name, 0, 80);
            }
            $alerts[] = [
                'event_key' => $eventKey,
                'court_id' => $courtId,
                'title' => 'Arrival due',
                'body' => $name . ' is due at ' . $startAt->format('H:i') . '.',
            ];
        }
        return ['ok' => true, 'alerts' => $alerts];
    }

    /** Keys for the bookings in this pass. Repeats collapse, and the list stops at 50. */
    public static function keys(array $bookings): array
    {
        $keys = [];
        foreach ($bookings as $booking) {
            $id = (int)($booking['id'] ?? 0);
            if ($id <= 0 || isset($keys[$id])) {
                continue;
            }
            $keys[$id] = 'arrival:' . $id;
            if (count($keys) >= 50) {
                break;
            }
        }
        return array_values($keys);
    }
}
