<?php

/**
 * What a refund webhook delivery is allowed to do.
 * A repeated body is a duplicate. A reconcile looks up the provider refund and does not create one.
 */
final class RefundWebhookPlan
{
    public const DUPLICATE = 'duplicate';
    public const IGNORE = 'ignore';
    public const RECONCILE = 'reconcile';

    public static function decide(bool $fingerprintSeen, bool $knownRefund): string
    {
        if ($fingerprintSeen) {
            return self::DUPLICATE;
        }
        if (!$knownRefund) {
            return self::IGNORE;
        }
        return self::RECONCILE;
    }

    public static function mayCreateProviderRefund(bool $reconcileOnly, ?string $providerStatus, ?string $providerRefundId): bool
    {
        if ($reconcileOnly || $providerStatus || $providerRefundId) {
            return false;
        }
        return true;
    }
}
