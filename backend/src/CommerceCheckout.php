<?php
require_once __DIR__ . '/CommerceSettings.php';

class CommerceCheckout {
    public static function validateTime(string $start, string $end, array $policy): void {
        $zone = new DateTimeZone('Asia/Kolkata');
        $a = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $start, $zone);
        $b = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $end, $zone);
        if (!$a || !$b || $a->format('Y-m-d H:i:s') !== $start || $b->format('Y-m-d H:i:s') !== $end || $b <= $a || $b->getTimestamp() - $a->getTimestamp() > 86400) throw new InvalidArgumentException('Invalid booking time range (maximum 24 hours)');
        if ($a->format('i:s') !== '00:00' && $a->format('i:s') !== '30:00') throw new InvalidArgumentException('Booking must start on a half-hour boundary');
        if ($b->format('i:s') !== '00:00' && $b->format('i:s') !== '30:00') throw new InvalidArgumentException('Booking must end on a half-hour boundary');
        $notice = ($a->getTimestamp() - time()) / 60;
        if ($notice < $policy['booking.minimum_notice_minutes']) throw new InvalidArgumentException('Booking is too close to the session start');
        if ($policy['booking.advance_hours'] > 0 && $notice > $policy['booking.advance_hours'] * 60) throw new InvalidArgumentException('Booking exceeds the advance booking window');
    }

    public static function quote(PDO $db, string $type, array $payload): array {
        require_once __DIR__ . '/Controllers/BookingController.php';
        $courtId = (int)($payload['court_id'] ?? 0);
        $stmt = $db->prepare('SELECT id FROM courts WHERE id = ?');
        $stmt->execute([$courtId]);
        if (!$stmt->fetchColumn()) throw new InvalidArgumentException('Venue not found');
        $policy = CommerceSettings::load($db, $courtId);
        if (!$policy['checkout.enabled']) throw new InvalidArgumentException('Online payments are currently paused');
        $subCourtId = !empty($payload['sub_court_id']) ? (int)$payload['sub_court_id'] : null;
        if ($subCourtId) {
            $stmt = $db->prepare('SELECT id FROM sub_courts WHERE id = ? AND court_id = ?');
            $stmt->execute([$subCourtId, $courtId]);
            if (!$stmt->fetchColumn()) throw new InvalidArgumentException('Space does not belong to this venue');
        }
        $amount = 0;
        $slotAmounts = [];
        if ($type === 'booking') {
            $slots = $payload['slots'] ?? [['start_time' => $payload['start_time'] ?? '', 'end_time' => $payload['end_time'] ?? '']];
            if (!is_array($slots) || !array_is_list($slots) || !$slots || count($slots) > 48) throw new InvalidArgumentException('Select between 1 and 48 time ranges');
            $calculator = new BookingController();
            foreach ($slots as $i => $slot) {
                self::validateTime((string)($slot['start_time'] ?? ''), (string)($slot['end_time'] ?? ''), $policy);
                foreach (array_slice($slots, 0, $i) as $other) {
                    if ($slot['start_time'] < $other['end_time'] && $slot['end_time'] > $other['start_time']) throw new InvalidArgumentException('Selected time ranges overlap');
                }
                $price = (int)round($calculator->calculateBookingPrice($courtId, $subCourtId, $slot['start_time'], $slot['end_time']) * 100);
                $slotAmounts[] = $price;
                $amount += $price;
            }
        } elseif ($type === 'subscription') {
            $stmt = $db->prepare('SELECT price, duration_days, slot_type FROM plans WHERE id = ? AND court_id = ?');
            $stmt->execute([(int)($payload['plan_id'] ?? 0), $courtId]);
            $plan = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$plan) throw new InvalidArgumentException('Plan not found');
            $amount = (int)round((float)$plan['price'] * 100);
            $payload['duration_days'] = (int)$plan['duration_days'];
            $payload['slot_type'] = $plan['slot_type'];
        } else {
            throw new InvalidArgumentException('Invalid payment type');
        }
        if ($amount <= 0) throw new InvalidArgumentException('Venue price must be positive');
        $price = CommerceSettings::price($amount, $policy);
        $payload['total_price'] = $price['venue']['total'] / 100;
        $payload['court_id'] = $courtId;
        $payload['sub_court_id'] = $subCourtId;
        $payload['type'] = 'hourly';
        $snapshots = [];
        $allocated = ['venue' => ['base' => 0, 'tax' => 0, 'total' => 0], 'fee' => ['base' => 0, 'tax' => 0, 'total' => 0]];
        foreach ($slotAmounts as $i => $raw) {
            $parts = [];
            foreach (['venue', 'fee'] as $component) {
                foreach (['base', 'tax'] as $field) {
                    $value = $i === count($slotAmounts) - 1 ? $price[$component][$field] - $allocated[$component][$field] : (int)floor($price[$component][$field] * $raw / $amount);
                    $parts[$component][$field] = $value;
                    $allocated[$component][$field] += $value;
                }
                $parts[$component]['total'] = $parts[$component]['base'] + $parts[$component]['tax'];
            }
            $parts['total'] = $parts['venue']['total'] + $parts['fee']['total'];
            $payload['slots'][$i] = ['start_time' => $slots[$i]['start_time'], 'end_time' => $slots[$i]['end_time'], 'total_price' => $parts['venue']['total'] / 100];
            $snapshots[] = ['version' => 1, 'policy' => $policy, 'price' => $parts];
        }
        $snapshot = ['version' => 1, 'policy' => $policy, 'price' => $price, 'slots' => $snapshots, 'processing_estimate' => CommerceSettings::estimateCost($price['total'], $policy)];
        $hash = hash('sha256', json_encode([$type, $payload, $snapshot]));
        return ['payload' => $payload, 'snapshot' => $snapshot, 'quote_hash' => $hash, 'amount' => $price['total'] / 100];
    }
}
