<?php

/**
 * Collected payments and payouts are different totals.
 * Pass collected only after successful refunds have been removed.
 * A confirmed booking price is not an input here.
 */
class SettlementMath
{
    public static function notYetPaidOut(float $collected, float $paidOut): float
    {
        return round($collected - $paidOut, 2);
    }
}
