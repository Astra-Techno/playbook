<?php

/**
 * Owner desk walk-ins may be entered after the hour for billing.
 * Status stays confirmed; past starts are marked checked_in at create.
 */
final class WalkInBilling
{
    /** True when the booking start is at or before now (Asia/Kolkata). */
    public static function startHasPassed(string $start, ?DateTimeImmutable $now = null): bool
    {
        $zone = new DateTimeZone('Asia/Kolkata');
        $startAt = new DateTimeImmutable($start, $zone);
        $nowAt = $now ?? new DateTimeImmutable('now', $zone);
        return $startAt->getTimestamp() <= $nowAt->getTimestamp();
    }

    /**
     * Attendance to set when creating a walk-in. Null when the hour is still ahead.
     *
     * @return 'checked_in'|null
     */
    public static function attendanceOnCreate(bool $isWalkIn, string $start, ?DateTimeImmutable $now = null): ?string
    {
        if (!$isWalkIn) {
            return null;
        }
        if (!self::startHasPassed($start, $now)) {
            return null;
        }
        return 'checked_in';
    }
}
