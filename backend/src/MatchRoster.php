<?php

/** How many extra players a host still needs. The host already has a seat. */
class MatchRoster
{
    public static function spotsLeft(int $playersNeeded, int $participantCount): int
    {
        $needed = max(1, $playersNeeded);
        $others = max(0, $participantCount - 1);
        return max(0, $needed - $others);
    }

    public static function isFull(int $playersNeeded, int $participantCount): bool
    {
        return self::spotsLeft($playersNeeded, $participantCount) === 0;
    }
}
