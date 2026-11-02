<?php

require_once __DIR__ . '/../VenueReport.php';

class VenueReportController
{
    public function show(int $courtId): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $court = $db->prepare('SELECT id, owner_id FROM courts WHERE id = ?');
        $court->execute([$courtId]);
        $venue = $court->fetch(PDO::FETCH_ASSOC);
        if (!$venue) {
            http_response_code(404);
            echo json_encode(['message' => 'Venue not found']);
            return;
        }
        if (!VenueReport::canView(($authUser['role'] ?? '') === 'admin', (int)$venue['owner_id'] === $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return;
        }
        $zone = new DateTimeZone('Asia/Kolkata');
        $today = new DateTime('now', $zone);
        $from = $this->day($_GET['from'] ?? null, $today->modify('-29 days')->format('Y-m-d'));
        $to = $this->day($_GET['to'] ?? null, (new DateTime('now', $zone))->format('Y-m-d'));
        if ($from === null || $to === null || $from > $to) {
            http_response_code(400);
            echo json_encode(['message' => 'from and to must be dates, with from on or before to']);
            return;
        }

        $bookings = $db->prepare("
            SELECT status, total_price, user_id
            FROM bookings
            WHERE court_id = ? AND DATE(start_time) >= ? AND DATE(start_time) <= ?
        ");
        $bookings->execute([$courtId, $from, $to]);

        $bookingPay = $db->prepare("
            SELECT COALESCE(SUM(
                p.amount - COALESCE((
                    SELECT SUM(r.amount_paise) / 100 FROM refund_requests r
                    WHERE r.payment_id = p.id AND r.status = 'success'
                ), 0)
            ), 0)
            FROM payments p
            JOIN bookings b ON p.type = 'booking' AND p.reference_id = b.id
            WHERE b.court_id = ? AND p.status IN ('paid','demo')
              AND DATE(b.start_time) >= ? AND DATE(b.start_time) <= ?
        ");
        $bookingPay->execute([$courtId, $from, $to]);

        $subscriptionPay = $db->prepare("
            SELECT COALESCE(SUM(
                p.amount - COALESCE((
                    SELECT SUM(r.amount_paise) / 100 FROM refund_requests r
                    WHERE r.payment_id = p.id AND r.status = 'success'
                ), 0)
            ), 0)
            FROM payments p
            JOIN user_subscriptions s ON p.type = 'subscription' AND p.reference_id = s.id
            WHERE s.court_id = ? AND p.status IN ('paid','demo')
              AND DATE(p.created_at) >= ? AND DATE(p.created_at) <= ?
        ");
        $subscriptionPay->execute([$courtId, $from, $to]);

        $collected = (float)$bookingPay->fetchColumn() + (float)$subscriptionPay->fetchColumn();
        echo json_encode([
            'from' => $from,
            'to' => $to,
            'report' => VenueReport::build($bookings->fetchAll(PDO::FETCH_ASSOC), $collected),
        ]);
    }

    private function day(mixed $value, string $fallback): ?string
    {
        if ($value === null || $value === '') {
            return $fallback;
        }
        $value = (string)$value;
        return preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) === 1 ? $value : null;
    }
}
