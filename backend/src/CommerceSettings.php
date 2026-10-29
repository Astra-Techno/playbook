<?php

/** Versioned, typed commercial policy. Credentials remain in server configuration. */
class CommerceSettings {
    public const KEY = 'commerce_policy';

    public static function schema(): array {
        return [
            'company.name' => ['Company', 'Legal name', 'text', 'PRIMEAXIS SOFTWARE PRIVATE LIMITED'],
            'company.gst_registered' => ['Company', 'Company is GST registered', 'bool', false],
            'company.gstin' => ['Company', 'Company GSTIN', 'gstin', ''],
            'checkout.enabled' => ['Booking', 'Accept new online payments', 'bool', true],
            'booking.advance_hours' => ['Booking', 'Maximum advance booking hours (0 = unlimited)', 'number', 0, 0, 8760],
            'booking.minimum_notice_minutes' => ['Booking', 'Minimum notice before play (minutes)', 'number', 0, 0, 10080],
            'fee.enabled' => ['Platform fee', 'Charge a platform fee', 'bool', false],
            'fee.mode' => ['Platform fee', 'Fee calculation', 'enum', 'fixed', ['fixed', 'percentage']],
            'fee.amount' => ['Platform fee', 'Fee amount (INR) or percentage', 'number', 10, 0, 10000],
            'fee.gst_rate' => ['Platform fee', 'Platform fee GST (%)', 'number', 18, 0, 40],
            'fee.tax_inclusive' => ['Platform fee', 'Entered fee includes GST', 'bool', true],
            'venue.gst_registered' => ['Venue tax defaults', 'Default venue GST registered', 'bool', false],
            'venue.gstin' => ['Venue tax defaults', 'Default venue GSTIN', 'gstin', ''],
            'venue.gst_rate' => ['Venue tax defaults', 'Venue GST (%) - verify service classification', 'number', 18, 0, 40],
            'venue.tax_inclusive' => ['Venue tax defaults', 'Venue prices include GST', 'bool', true],
            'cancellation.enabled' => ['Cancellation', 'Allow customer cancellation before play', 'bool', true],
            'cancellation.full_hours' => ['Cancellation', 'Full-refund notice (hours)', 'number', 12, 0, 720],
            'cancellation.partial_hours' => ['Cancellation', 'Partial-refund notice (hours)', 'number', 6, 0, 720],
            'cancellation.partial_percent' => ['Cancellation', 'Partial refund of venue charge (%)', 'number', 50, 0, 100],
            'cancellation.late_percent' => ['Cancellation', 'Late cancellation refund of venue charge (%)', 'number', 0, 0, 100],
            'cancellation.fee_refund' => ['Cancellation', 'Platform fee refunded on customer cancellation', 'enum', 'full_refund_only', ['always', 'full_refund_only', 'never']],
            'refund.expected_days' => ['Refunds', 'Expected refund credit time (business days)', 'number', 7, 1, 30],
            'refund.automation_enabled' => ['Refund automation', 'Automatically submit eligible refunds', 'bool', false],
            'refund.auto_limit_inr' => ['Refund automation', 'Maximum automatic refund (INR)', 'number', 10000, 1, 1000000],
            'refund.max_checks' => ['Refund automation', 'Maximum status checks before review', 'number', 672, 1, 10000],
            'refund.max_attempts' => ['Refund automation', 'Maximum submission attempts before review', 'number', 5, 1, 20],
            'refund.retry_minutes' => ['Refund automation', 'Retry delay (minutes)', 'number', 5, 1, 60],
            'refund.poll_minutes' => ['Refund automation', 'Pending refund status check interval (minutes)', 'number', 15, 1, 1440],
            'refund.max_pending_hours' => ['Refund automation', 'Escalate pending refunds after (hours)', 'number', 168, 1, 720],
            'settlement.split_enabled' => ['Settlement', 'Use Cashfree Easy Split for active vendors', 'bool', true],
            'settlement.commission_percent' => ['Settlement', 'Default venue commission (%)', 'number', 10, 0, 100],
            'settlement.gateway_percent' => ['Cost estimates', 'Estimated gateway cost (%)', 'number', 1.95, 0, 100],
            'settlement.split_percent' => ['Cost estimates', 'Estimated split cost (%)', 'number', 0.25, 0, 100],
            'settlement.cost_gst_percent' => ['Cost estimates', 'GST on processing cost (%)', 'number', 18, 0, 40],
        ];
    }

    public static function defaults(): array {
        return array_map(fn($field) => $field[3], self::schema());
    }

    public static function normalize(array $values): array {
        $schema = self::schema();
        if (array_diff(array_keys($values), array_keys($schema))) throw new InvalidArgumentException('Unknown setting');
        $result = self::defaults();
        foreach ($values as $key => $value) {
            $field = $schema[$key];
            if ($field[2] === 'bool') {
                if (!is_bool($value)) throw new InvalidArgumentException("$key must be true or false");
            } elseif ($field[2] === 'number') {
                if (!is_int($value) && !is_float($value)) throw new InvalidArgumentException("$key must be a number");
                if (!is_finite((float)$value) || $value < $field[4] || $value > $field[5]) throw new InvalidArgumentException("$key is outside the allowed range");
                if (in_array($key, ['refund.max_checks','refund.max_attempts','refund.retry_minutes','refund.poll_minutes','refund.max_pending_hours'], true) && floor($value) != $value) throw new InvalidArgumentException("$key must be a whole number");
                $value = round($value, 2);
            } elseif ($field[2] === 'enum') {
                if (!in_array($value, $field[4], true)) throw new InvalidArgumentException("Invalid $key");
            } else {
                if (!is_string($value) || strlen($value) > 250) throw new InvalidArgumentException("Invalid $key");
                $value = trim($value);
                if ($field[2] === 'gstin' && $value !== '' && !preg_match('/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/', $value)) throw new InvalidArgumentException("Invalid GSTIN in $key");
            }
            $result[$key] = $value;
        }
        foreach (['company', 'venue'] as $scope) {
            if ($result["$scope.gst_registered"] && $result["$scope.gstin"] === '') throw new InvalidArgumentException("$scope GSTIN is required when GST registration is enabled");
        }
        if ($result['fee.mode'] === 'percentage' && $result['fee.amount'] > 100) throw new InvalidArgumentException('Percentage fee cannot exceed 100');
        if ($result['cancellation.partial_hours'] > $result['cancellation.full_hours']) throw new InvalidArgumentException('Partial-refund notice must not exceed full-refund notice');
        if ($result['cancellation.late_percent'] > $result['cancellation.partial_percent']) throw new InvalidArgumentException('Late refund cannot exceed partial refund');
        return $result;
    }

    public static function load(PDO $db, ?int $courtId = null): array {
        $stmt = $db->prepare('SELECT `key`, `value` FROM config WHERE `key` IN (?, ?, ?)');
        $stmt->execute([self::KEY, self::KEY . '.venue.' . (int)$courtId, 'platform_commission_pct']);
        $rows = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
        $base = self::defaults();
        if (isset($rows['platform_commission_pct']) && is_numeric($rows['platform_commission_pct'])) $base['settlement.commission_percent'] = (float)$rows['platform_commission_pct'];
        if (isset($rows[self::KEY])) $base = self::normalize(array_replace($base, json_decode($rows[self::KEY], true, 512, JSON_THROW_ON_ERROR)));
        $override = json_decode($rows[self::KEY . '.venue.' . (int)$courtId] ?? '{}', true, 512, JSON_THROW_ON_ERROR);
        return self::normalize(array_replace($base, $override));
    }

    public static function tax(int $amount, float $rate, bool $inclusive): array {
        $base = $inclusive ? (int)round($amount / (1 + $rate / 100)) : $amount;
        $tax = $inclusive ? $amount - $base : (int)round($base * $rate / 100);
        return ['base' => $base, 'tax' => $tax, 'total' => $base + $tax];
    }

    /** All monetary calculations use integer paise. */
    public static function price(int $venuePaise, array $policy): array {
        $venue = self::tax($venuePaise, $policy['venue.gst_registered'] ? $policy['venue.gst_rate'] : 0, $policy['venue.tax_inclusive']);
        $feePaise = !$policy['fee.enabled'] ? 0 : ($policy['fee.mode'] === 'fixed' ? (int)round($policy['fee.amount'] * 100) : (int)round($venue['total'] * $policy['fee.amount'] / 100));
        $fee = self::tax($feePaise, $policy['company.gst_registered'] ? $policy['fee.gst_rate'] : 0, $policy['fee.tax_inclusive']);
        return ['venue' => $venue, 'fee' => $fee, 'total' => $venue['total'] + $fee['total']];
    }

    public static function refund(array $snapshot, float $hoursNotice, bool $venueCancelled): array {
        $policy = $snapshot['policy'];
        $percent = $venueCancelled || $hoursNotice >= $policy['cancellation.full_hours'] ? 100 : ($hoursNotice >= $policy['cancellation.partial_hours'] ? $policy['cancellation.partial_percent'] : $policy['cancellation.late_percent']);
        $feeRefund = $venueCancelled || $policy['cancellation.fee_refund'] === 'always' || ($percent >= 100 && $policy['cancellation.fee_refund'] === 'full_refund_only');
        $venue = (int)round($snapshot['price']['venue']['total'] * $percent / 100);
        $fee = $feeRefund ? $snapshot['price']['fee']['total'] : 0;
        return ['venue' => $venue, 'fee' => $fee, 'total' => $venue + $fee, 'venue_percent' => $percent];
    }

    public static function estimateCost(int $paidPaise, array $policy): array {
        $gateway = (int)round($paidPaise * $policy['settlement.gateway_percent'] / 100);
        $split = $policy['settlement.split_enabled'] ? (int)round($paidPaise * $policy['settlement.split_percent'] / 100) : 0;
        $tax = (int)round(($gateway + $split) * $policy['settlement.cost_gst_percent'] / 100);
        return ['gateway' => $gateway, 'split' => $split, 'tax' => $tax, 'total' => $gateway + $split + $tax, 'estimate_only' => true];
    }
}
