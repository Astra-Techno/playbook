<?php

/** How a walk-in price is recorded. Online bookings leave this empty. */
class CollectionMethod
{
    public const ALLOWED = ['pay_at_venue', 'cash', 'external_upi'];

    /** @return string|false */
    public static function forWalkIn(mixed $value): string|false
    {
        if ($value === null || $value === '') {
            return 'pay_at_venue';
        }
        $value = trim((string)$value);
        return in_array($value, self::ALLOWED, true) ? $value : false;
    }
}
