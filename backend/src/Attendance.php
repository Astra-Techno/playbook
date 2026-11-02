<?php

/**
 * Arrival marks on a confirmed booking. Status is unchanged.
 * Times are Asia/Kolkata wall clocks, Y-m-d H:i:s.
 */
final class Attendance
{
    public const EARLY_MINUTES = 30;
    public const GRACE_MINUTES = 15;

    /** @return array{ok:bool,attendance?:string,message:string} */
    public static function decide(string $action, ?string $current, string $status, string $start, string $end, string $now): array
    {
        $zone = new DateTimeZone('Asia/Kolkata');
        $startAt = new DateTimeImmutable($start, $zone);
        $endAt = new DateTimeImmutable($end, $zone);
        $nowAt = new DateTimeImmutable($now, $zone);

        if ($status !== 'confirmed') {
            return ['ok' => false, 'message' => 'Only a confirmed booking can be marked.'];
        }
        if ($current === 'checked_in') {
            return ['ok' => false, 'message' => 'This booking is already checked in.'];
        }
        if ($current === 'no_show') {
            return ['ok' => false, 'message' => 'This booking is already marked as a no-show.'];
        }
        if ($action === 'check_in') {
            $opens = $startAt->modify('-' . self::EARLY_MINUTES . ' minutes');
            if ($nowAt < $opens) {
                return ['ok' => false, 'message' => 'Check-in opens 30 minutes before the start.'];
            }
            if ($nowAt >= $endAt) {
                return ['ok' => false, 'message' => 'Check-in closes when the booking ends.'];
            }
            return ['ok' => true, 'attendance' => 'checked_in', 'message' => 'Checked in.'];
        }
        if ($action === 'no_show') {
            $opens = $startAt->modify('+' . self::GRACE_MINUTES . ' minutes');
            if ($nowAt < $opens) {
                return ['ok' => false, 'message' => 'A no-show can be marked 15 minutes after the start.'];
            }
            return ['ok' => true, 'attendance' => 'no_show', 'message' => 'Marked as a no-show.'];
        }
        return ['ok' => false, 'message' => 'action must be check_in or no_show.'];
    }
}
