<?php

require_once __DIR__ . '/MemberCheckIn.php';

/**
 * Freeze (pause) a membership and remind members. Dates are 'Y-m-d' in venue time.
 * A freeze pushes the end date out by the frozen days; ending a freeze early gives the
 * unused days back. Each membership can be frozen for at most MAX_DAYS in total.
 */
final class MembershipCare
{
    public const MAX_DAYS = 60;
    public const MAX_PER_FREEZE = 30;

    public static function isFrozen(?string $from, ?string $until, string $today): bool
    {
        return $from !== null && $from !== '' && $until !== null && $until !== ''
            && $today >= substr($from, 0, 10) && $today <= substr($until, 0, 10);
    }

    /** @return array{ok:bool,message:string,from?:string,until?:string,end?:string,used?:int} */
    public static function freeze(string $status, string $endDate, ?string $frozenUntil, int $usedDays, int $days, string $today): array
    {
        $end = substr($endDate, 0, 10);
        if ($status !== 'active' || $today > $end) {
            return ['ok' => false, 'message' => 'Only an active membership can be frozen.'];
        }
        if ($days < 1 || $days > self::MAX_PER_FREEZE) {
            return ['ok' => false, 'message' => 'Freeze for 1 to ' . self::MAX_PER_FREEZE . ' days.'];
        }
        if ($frozenUntil !== null && $frozenUntil !== '' && substr($frozenUntil, 0, 10) >= $today) {
            return ['ok' => false, 'message' => 'Already frozen until ' . substr($frozenUntil, 0, 10) . '.'];
        }
        $left = self::MAX_DAYS - max(0, $usedDays);
        if ($days > $left) {
            return ['ok' => false, 'message' => $left > 0 ? "Only $left freeze days left on this membership." : 'No freeze days left on this membership.'];
        }
        $start = new DateTimeImmutable($today);
        return [
            'ok' => true,
            'message' => "Frozen for $days " . ($days === 1 ? 'day' : 'days') . '.',
            'from' => $today,
            'until' => $start->modify('+' . ($days - 1) . ' days')->format('Y-m-d'),
            'end' => (new DateTimeImmutable($end))->modify("+$days days")->format('Y-m-d'),
            'used' => max(0, $usedDays) + $days,
        ];
    }

    /**
     * End a freeze today. The member can come in today, so today and the rest are given back.
     * @return array{ok:bool,message:string,from?:?string,until?:?string,end?:string,used?:int}
     */
    public static function unfreeze(?string $from, ?string $until, string $endDate, int $usedDays, string $today): array
    {
        if (!self::isFrozen($from, $until, $today)) {
            return ['ok' => false, 'message' => 'This membership is not frozen.'];
        }
        $now = new DateTimeImmutable($today);
        $unused = (int)$now->diff(new DateTimeImmutable(substr((string)$until, 0, 10)))->days + 1;
        $startedToday = substr((string)$from, 0, 10) === $today;
        return [
            'ok' => true,
            'message' => 'Welcome back. ' . $unused . ' unused ' . ($unused === 1 ? 'day' : 'days') . ' returned.',
            'from' => $startedToday ? null : substr((string)$from, 0, 10),
            'until' => $startedToday ? null : $now->modify('-1 day')->format('Y-m-d'),
            'end' => (new DateTimeImmutable(substr($endDate, 0, 10)))->modify("-$unused days")->format('Y-m-d'),
            'used' => max(0, $usedDays - $unused),
        ];
    }

    /** Message for a reminder the venue sends: renew when ending within a week, else "we miss you". */
    public static function reminder(string $venue, string $endDate, string $today): array
    {
        $left = MemberCheckIn::daysLeft($endDate, $today);
        if ($left <= 7) {
            $when = $left <= 1 ? 'today' : ($left === 2 ? 'tomorrow' : "in $left days");
            return [
                'kind' => 'renew',
                'title' => "Your $venue membership ends $when",
                'body' => 'Renew in the KoCourt app or at the desk to keep going.',
            ];
        }
        return [
            'kind' => 'quiet',
            'title' => "We miss you at $venue",
            'body' => 'Your membership is active till ' . (new DateTimeImmutable(substr($endDate, 0, 10)))->format('j M') . '. Drop in this week.',
        ];
    }

    /** Automatic renewal reminders go out 3 days before the end and on the last day. */
    public static function autoReminderDue(string $endDate, string $today): bool
    {
        $left = MemberCheckIn::daysLeft($endDate, $today);
        return $left === 3 || $left === 1;
    }
}
