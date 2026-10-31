<?php

/**
 * Pricing and closure decisions shared by booking price, the quote API,
 * and availability. No database. Callers pass rows they already loaded.
 *
 * Price order, unchanged: a matching facility rule beats a venue rule.
 * Inside one scope, higher priority wins, then the newer id. Otherwise the
 * facility hourly rate is used when it is above zero, then the venue rate.
 * A range is summed in 30-minute steps. The weekday/weekend choice follows
 * the start of the range. Each step still uses its own calendar date for
 * valid_from / valid_to.
 */
class ScheduleRules
{
    public static function dayType(string $date): string
    {
        $dow = (int)date('N', strtotime($date));
        return $dow >= 6 ? 'weekend' : 'weekday';
    }

    public static function baseRate(float $venueRate, $facilityRate): float
    {
        if ($facilityRate !== null && $facilityRate !== '' && (float)$facilityRate > 0) {
            return (float)$facilityRate;
        }
        return $venueRate;
    }

    public static function splitRules(array $rules, ?int $subCourtId): array
    {
        $facility = [];
        $venue = [];
        foreach ($rules as $rule) {
            if (!is_array($rule)) {
                continue;
            }
            $scope = $rule['sub_court_id'] ?? null;
            if ($scope === null || $scope === '') {
                $venue[] = $rule;
                continue;
            }
            if ($subCourtId !== null && (int)$scope === $subCourtId) {
                $facility[] = $rule;
            }
        }
        return ['facility' => $facility, 'venue' => $venue];
    }

    public static function ruleMatches(array $rule, int $hour, string $dayType, string $date): bool
    {
        $start = (int)($rule['start_hour'] ?? 0);
        $end = (int)($rule['end_hour'] ?? 0);
        if (!($start <= $hour && $end > $hour)) {
            return false;
        }
        $type = $rule['day_type'] ?? 'all';
        if ($type !== 'all' && $type !== $dayType) {
            return false;
        }
        $from = $rule['valid_from'] ?? null;
        $to = $rule['valid_to'] ?? null;
        if ($from !== null && $from !== '' && $from > $date) {
            return false;
        }
        if ($to !== null && $to !== '' && $to < $date) {
            return false;
        }
        return true;
    }

    public static function pickRule(array $rules, int $hour, string $dayType, string $date): ?array
    {
        $best = null;
        foreach ($rules as $rule) {
            if (!is_array($rule) || !self::ruleMatches($rule, $hour, $dayType, $date)) {
                continue;
            }
            if ($best === null || self::outranks($rule, $best)) {
                $best = $rule;
            }
        }
        return $best;
    }

    private static function outranks(array $candidate, array $current): bool
    {
        $priority = (int)($candidate['priority'] ?? 0);
        $currentPriority = (int)($current['priority'] ?? 0);
        if ($priority !== $currentPriority) {
            return $priority > $currentPriority;
        }
        return (int)($candidate['id'] ?? 0) > (int)($current['id'] ?? 0);
    }

    public static function hourlyRate(array $facilityRules, array $venueRules, float $base, int $hour, string $dayType, string $date): array
    {
        $rule = self::pickRule($facilityRules, $hour, $dayType, $date);
        if ($rule === null) {
            $rule = self::pickRule($venueRules, $hour, $dayType, $date);
        }
        return [
            'effective_price' => $rule ? (float)$rule['price'] : $base,
            'rule' => $rule,
        ];
    }

    public static function quote(string $start, string $end, float $base, array $facilityRules, array $venueRules): float
    {
        $startTs = strtotime($start);
        $endTs = strtotime($end);
        if ($startTs === false || $endTs === false || $endTs <= $startTs) {
            return $base;
        }
        $dayType = self::dayType(date('Y-m-d', $startTs));
        $total = 0.0;
        $cursor = $startTs;
        while ($cursor < $endTs) {
            $hour = (int)date('H', $cursor);
            $slotDate = date('Y-m-d', $cursor);
            $rate = self::hourlyRate($facilityRules, $venueRules, $base, $hour, $dayType, $slotDate);
            $total += $rate['effective_price'] / 2;
            $cursor += 1800;
        }
        return round($total, 2);
    }

    /**
     * Shared mode counts confirmed booking rows, not people.
     * Any other mode is exclusive: one confirmed overlap closes the slot.
     */
    public static function capacityAllows(string $mode, int $confirmedRows, int $capacity): bool
    {
        if ($mode === 'shared') {
            return $confirmedRows < max(1, $capacity);
        }
        return $confirmedRows === 0;
    }

    /**
     * A venue-wide block (no facility id) covers every facility.
     * A facility block covers only that facility, including when the
     * request itself has no facility.
     */
    public static function blockAppliesToRequest(?int $blockSubCourtId, ?int $requestSubCourtId): bool
    {
        if ($blockSubCourtId === null) {
            return true;
        }
        return $requestSubCourtId !== null && $blockSubCourtId === $requestSubCourtId;
    }

    public static function intervalsOverlap(string $startA, string $endA, string $startB, string $endB): bool
    {
        $a1 = strtotime($startA);
        $a2 = strtotime($endA);
        $b1 = strtotime($startB);
        $b2 = strtotime($endB);
        if ($a1 === false || $a2 === false || $b1 === false || $b2 === false) {
            return false;
        }
        return $a1 < $b2 && $a2 > $b1;
    }

    /**
     * Annual template: same month and day as the booking start.
     * A template that ends at or before its start clock runs into the next day.
     * A booking that starts the following morning does not match a template
     * whose start date is the previous day.
     */
    public static function annualTemplateHits(string $bookingStart, string $bookingEnd, string $templateStart, string $templateEnd): bool
    {
        $bookingStartTs = strtotime($bookingStart);
        $bookingEndTs = strtotime($bookingEnd);
        $templateStartTs = strtotime($templateStart);
        $templateEndTs = strtotime($templateEnd);
        if ($bookingStartTs === false || $bookingEndTs === false || $templateStartTs === false || $templateEndTs === false) {
            return false;
        }
        if ((int)date('n', $templateStartTs) !== (int)date('n', $bookingStartTs)
            || (int)date('j', $templateStartTs) !== (int)date('j', $bookingStartTs)) {
            return false;
        }
        $bookingDate = date('Y-m-d', $bookingStartTs);
        $virtualStart = strtotime($bookingDate . ' ' . date('H:i:s', $templateStartTs));
        $virtualEnd = strtotime($bookingDate . ' ' . date('H:i:s', $templateEndTs));
        if ($virtualStart === false || $virtualEnd === false) {
            return false;
        }
        if ($virtualEnd <= $virtualStart) {
            $virtualEnd += 86400;
        }
        return $bookingStartTs < $virtualEnd && $bookingEndTs > $virtualStart;
    }

    /**
     * Same-day hours when close is after open.
     * When close is at or before open, the venue runs past midnight:
     * a window may sit in the evening, in the next morning, or cross midnight once.
     */
    public static function windowInsideHours(string $open, string $close, string $start, string $end): bool
    {
        $open = substr($open, 0, 8);
        $close = substr($close, 0, 8);
        $startTs = strtotime($start);
        $endTs = strtotime($end);
        if ($startTs === false || $endTs === false || $endTs <= $startTs) {
            return false;
        }
        $startDate = date('Y-m-d', $startTs);
        $endDate = date('Y-m-d', $endTs);
        $t1 = date('H:i:s', $startTs);
        $t2 = date('H:i:s', $endTs);
        $sameDay = $startDate === $endDate;
        if ($close > $open) {
            if (!$sameDay) {
                return false;
            }
            return $t1 >= $open && $t2 <= $close;
        }
        if ($sameDay) {
            $evening = $t1 >= $open && $t2 >= $open && $t2 > $t1;
            $morning = $t1 < $open && $t2 <= $close && $t1 < $t2;
            return $evening || $morning;
        }
        $next = date('Y-m-d', strtotime($startDate . ' +1 day'));
        return $endDate === $next && $t1 >= $open && $t2 <= $close;
    }

    /** Clock times of an annual block placed on the requested calendar date. */
    public static function appliesWindow(string $start, string $end, bool $repeatAnnually, ?string $onDate): array
    {
        if (!$repeatAnnually || $onDate === null || $onDate === '') {
            return [$start, $end];
        }
        $startTs = strtotime($start);
        $endTs = strtotime($end);
        if ($startTs === false || $endTs === false) {
            return [$start, $end];
        }
        $startClock = date('H:i:s', $startTs);
        $endClock = date('H:i:s', $endTs);
        $endDate = $onDate;
        if ($endClock <= $startClock) {
            $endDate = date('Y-m-d', strtotime($onDate . ' +1 day'));
        }
        return [$onDate . ' ' . $startClock, $endDate . ' ' . $endClock];
    }
}
