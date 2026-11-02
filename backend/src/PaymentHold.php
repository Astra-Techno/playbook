<?php

/**
 * A short reservation while a booking payment is unfinished.
 * Booking status stays pending, confirmed, or cancelled.
 * An active hold blocks the slot. An expired or released hold does not.
 */
final class PaymentHold
{
    public const MINUTES = 10;

    public static function expiresAt(string $now): string
    {
        $zone = new DateTimeZone('Asia/Kolkata');
        return (new DateTimeImmutable($now, $zone))->modify('+' . self::MINUTES . ' minutes')->format('Y-m-d H:i:s');
    }

    public static function blocks(?string $releasedAt, string $expiresAt, string $now, ?int $paymentId, int $ignorePaymentId): bool
    {
        if ($releasedAt !== null && $releasedAt !== '') {
            return false;
        }
        if ($expiresAt <= $now) {
            return false;
        }
        if ($ignorePaymentId > 0 && $paymentId === $ignorePaymentId) {
            return false;
        }
        return true;
    }

    /** @return list<array{start:string,end:string,sub_court_id:?int}> */
    public static function slots(array $payload): array
    {
        $sub = null;
        if (isset($payload['sub_court_id']) && $payload['sub_court_id'] !== '' && $payload['sub_court_id'] !== null) {
            $sub = (int)$payload['sub_court_id'];
        }
        $raw = (isset($payload['slots']) && is_array($payload['slots'])) ? $payload['slots'] : null;
        if ($raw === null && !empty($payload['start_time']) && !empty($payload['end_time'])) {
            $raw = [['start_time' => $payload['start_time'], 'end_time' => $payload['end_time']]];
        }
        $slots = [];
        foreach ($raw ?? [] as $slot) {
            if (!is_array($slot) || empty($slot['start_time']) || empty($slot['end_time'])) {
                continue;
            }
            $slots[] = [
                'start' => (string)$slot['start_time'],
                'end' => (string)$slot['end_time'],
                'sub_court_id' => $sub,
            ];
        }
        return $slots;
    }

    /** @param list<array{start:string,end:string,sub_court_id:?int}> $slots */
    public static function place(PDO $db, string $holdKey, int $userId, int $courtId, array $slots, string $now): void
    {
        $expires = self::expiresAt($now);
        $stmt = $db->prepare(
            "INSERT INTO booking_holds (hold_key, user_id, court_id, sub_court_id, start_time, end_time, expires_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)"
        );
        foreach ($slots as $slot) {
            $stmt->execute([
                $holdKey,
                $userId,
                $courtId,
                $slot['sub_court_id'],
                $slot['start'],
                $slot['end'],
                $expires,
            ]);
        }
    }

    public static function attach(PDO $db, string $holdKey, int $paymentId): void
    {
        $db->prepare("UPDATE booking_holds SET payment_id = ? WHERE hold_key = ? AND payment_id IS NULL")
            ->execute([$paymentId, $holdKey]);
    }

    public static function releaseKey(PDO $db, string $holdKey, string $now): void
    {
        $db->prepare("UPDATE booking_holds SET released_at = ? WHERE hold_key = ? AND released_at IS NULL")
            ->execute([$now, $holdKey]);
    }

    public static function releasePayment(PDO $db, int $paymentId, string $now): void
    {
        $db->prepare("UPDATE booking_holds SET released_at = ? WHERE payment_id = ? AND released_at IS NULL")
            ->execute([$now, $paymentId]);
    }
}
