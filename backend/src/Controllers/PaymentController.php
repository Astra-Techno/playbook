<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/cashfree.php';

class PaymentController {

    // ── Private Helpers ────────────────────────────────────────────────────────

    /** Shared cURL helper for Cashfree API calls */
    private function cfRequest(string $method, string $endpoint, array $body = []): array {
        $url = CASHFREE_BASE_URL . $endpoint;
        $ch  = curl_init($url);

        $headers = [
            'x-client-id: '     . CASHFREE_APP_ID,
            'x-client-secret: ' . CASHFREE_SECRET_KEY,
            'x-api-version: '   . CASHFREE_API_VERSION,
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT        => 15,
        ]);

        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
        }

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return ['code' => $httpCode, 'data' => json_decode($response, true)];
    }

    /** Peak-hour classification (same logic as BookingController) */
    private function getPeakType(string $startDatetime, array $court): ?string {
        $time = date('H:i:s', strtotime($startDatetime));
        $mps  = $court['morning_peak_start'] ?? '05:00:00';
        $mpe  = $court['morning_peak_end']   ?? '09:00:00';
        $eps  = $court['evening_peak_start'] ?? '17:00:00';
        $epe  = $court['evening_peak_end']   ?? '21:00:00';
        if ($time >= $mps && $time < $mpe) return 'morning';
        if ($time >= $eps && $time < $epe) return 'evening';
        return null;
    }

    /** Returns true when real Cashfree credentials are not yet configured */
    private function isDemoMode(): bool {
        return !CASHFREE_APP_ID
            || CASHFREE_APP_ID === 'your_cashfree_app_id'
            || !CASHFREE_SECRET_KEY
            || CASHFREE_SECRET_KEY === 'your_cashfree_secret_key';
    }

    // ── POST /api/payments/create-order ───────────────────────────────────────
    // Body: { user_id, amount, type: 'booking'|'subscription', payload: {...} }
    public function createOrder(): void {
        $data    = json_decode(file_get_contents('php://input'));
        $user_id = (int)($data->user_id ?? 0);
        $amount  = round(floatval($data->amount ?? 0), 2);
        $type    = in_array($data->type ?? '', ['booking', 'subscription'])
                   ? $data->type : 'booking';

        if ($amount <= 0 || !$user_id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid amount or user_id']);
            return;
        }

        // Unique order ID (max 50 chars, alphanumeric/underscore/hyphen)
        $orderId = ($this->isDemoMode() ? 'demo_' : 'pb_') . $user_id . '_' . time();

        $db = Database::getConnection();

        // ── Demo mode: skip Cashfree entirely ────────────────────────────────
        if ($this->isDemoMode()) {
            $stmt = $db->prepare(
                "INSERT INTO payments (user_id, cf_order_id, amount, type, payload, status)
                 VALUES (?, ?, ?, ?, ?, 'demo')"
            );
            $stmt->execute([$user_id, $orderId, $amount, $type, json_encode($data->payload ?? new stdClass())]);
            http_response_code(200);
            echo json_encode(['order_id' => $orderId, 'demo' => true, 'amount' => $amount]);
            return;
        }

        // Fetch user info for customer_details (Cashfree requires phone)
        $uStmt   = $db->prepare("SELECT name, phone FROM users WHERE id = ?");
        $uStmt->execute([$user_id]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC) ?: [];

        $phone = preg_replace('/\D/', '', $user['phone'] ?? '9999999999');
        if (strlen($phone) < 10) $phone = '9999999999';

        // Create order on Cashfree
        $result = $this->cfRequest('POST', '/orders', [
            'order_id'         => $orderId,
            'order_amount'     => $amount,
            'order_currency'   => 'INR',
            'customer_details' => [
                'customer_id'    => 'user_' . $user_id,
                'customer_name'  => $user['name']  ?? 'Customer',
                'customer_phone' => $phone,
            ],
            'order_meta' => ['notify_url' => ''],
        ]);

        if ($result['code'] !== 200 || empty($result['data']['payment_session_id'])) {
            http_response_code(502);
            echo json_encode([
                'message' => 'Failed to create Cashfree order',
                'detail'  => $result['data']['message'] ?? 'Unknown error',
            ]);
            return;
        }

        $cfData           = $result['data'];
        $paymentSessionId = $cfData['payment_session_id'];

        $stmt = $db->prepare(
            "INSERT INTO payments (user_id, cf_order_id, amount, type, payload, status)
             VALUES (?, ?, ?, ?, ?, 'created')"
        );
        $stmt->execute([$user_id, $orderId, $amount, $type, json_encode($data->payload ?? new stdClass())]);

        http_response_code(200);
        echo json_encode([
            'order_id'           => $orderId,
            'payment_session_id' => $paymentSessionId,
            'env'                => CASHFREE_ENV,
            'amount'             => $amount,
        ]);
    }

    // ── POST /api/payments/verify ──────────────────────────────────────────────
    // Body: { order_id }  — sent by frontend after Cashfree checkout completes
    public function verify(): void {
        $data     = json_decode(file_get_contents('php://input'));
        $orderId  = trim($data->order_id ?? '');

        if (!$orderId) {
            http_response_code(400);
            echo json_encode(['message' => 'order_id is required']);
            return;
        }

        $db = Database::getConnection();

        // ── Demo mode: skip Cashfree verification ─────────────────────────────
        $isDemo = str_starts_with($orderId, 'demo_');

        if (!$isDemo) {
            // ── 1. Verify with Cashfree ────────────────────────────────────────
            $result = $this->cfRequest('GET', '/orders/' . $orderId);

            if ($result['code'] !== 200) {
                http_response_code(502);
                echo json_encode(['message' => 'Could not verify payment with Cashfree']);
                return;
            }

            $cfOrder     = $result['data'];
            $orderStatus = $cfOrder['order_status'] ?? 'UNKNOWN';

            if ($orderStatus !== 'PAID') {
                http_response_code(402);
                echo json_encode(['message' => 'Payment not completed. Status: ' . $orderStatus]);
                return;
            }
        }

        $cfPaymentId = $isDemo ? null : ($this->cfRequest('GET', '/orders/' . $orderId . '/payments')['data'][0]['cf_payment_id'] ?? null);

        // ── 2. Load our payment record ────────────────────────────────────────
        $stmt = $db->prepare(
            "SELECT * FROM payments WHERE cf_order_id = ? AND status IN ('created','demo')"
        );
        $stmt->execute([$orderId]);
        $payment = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$payment) {
            http_response_code(404);
            echo json_encode(['message' => 'Payment record not found or already processed']);
            return;
        }

        // Mark as paid
        $db->prepare(
            "UPDATE payments SET cf_payment_id = ?, status = 'paid' WHERE id = ?"
        )->execute([$cfPaymentId, $payment['id']]);

        $payload = json_decode($payment['payload'], true);

        // ── 3a. Create Booking ────────────────────────────────────────────────
        if ($payment['type'] === 'booking') {
            require_once __DIR__ . '/../Models/Booking.php';
            require_once __DIR__ . '/../Models/Subscription.php';
            $booking = new Booking();

            // Server-side peak-hours guard
            $cStmt = $db->prepare("SELECT * FROM courts WHERE id = ?");
            $cStmt->execute([(int)$payload['court_id']]);
            $court = $cStmt->fetch(PDO::FETCH_ASSOC);

            if ($court && $court['peak_members_only']) {
                $peakType = $this->getPeakType($payload['start_time'], $court);
                if ($peakType !== null) {
                    $sub    = new Subscription();
                    $active = $sub->getActive((int)$payload['user_id'], (int)$payload['court_id']);
                    if (!$active || !Subscription::coversSlot($active['slot_type'], $peakType)) {
                        $db->prepare(
                            "UPDATE payments SET status = 'refund_pending' WHERE id = ?"
                        )->execute([$payment['id']]);
                        http_response_code(403);
                        echo json_encode([
                            'message' => 'Peak hours are for members only. Contact support for a refund.',
                        ]);
                        return;
                    }
                }
            }

            // Race-condition guard: re-check slot availability
            if (!$booking->isSlotAvailable(
                $payload['court_id'],
                $payload['start_time'],
                $payload['end_time']
            )) {
                $db->prepare(
                    "UPDATE payments SET status = 'refund_pending' WHERE id = ?"
                )->execute([$payment['id']]);
                http_response_code(409);
                echo json_encode([
                    'message' => 'Slot was taken during payment. Contact support for a refund.',
                ]);
                return;
            }

            $booking->user_id     = (int)$payload['user_id'];
            $booking->court_id    = (int)$payload['court_id'];
            $booking->start_time  = $payload['start_time'];
            $booking->end_time    = $payload['end_time'];
            $booking->type        = $payload['type'] ?? 'hourly';
            $booking->total_price = $payload['total_price'];

            if ($booking->create()) {
                $bookingId = $db->lastInsertId();
                $db->prepare(
                    "UPDATE payments SET reference_id = ? WHERE id = ?"
                )->execute([$bookingId, $payment['id']]);
                http_response_code(200);
                echo json_encode(['message' => 'Booking confirmed!', 'booking_id' => $bookingId]);
            } else {
                http_response_code(503);
                echo json_encode(['message' => 'Booking creation failed after payment']);
            }

        // ── 3b. Activate Subscription ─────────────────────────────────────────
        } elseif ($payment['type'] === 'subscription') {
            require_once __DIR__ . '/../Models/Subscription.php';
            $sub = new Subscription();

            if ($sub->create(
                (int)$payload['user_id'],
                (int)$payload['plan_id'],
                (int)$payload['court_id'],
                $payload['slot_type'],
                (int)$payload['duration_days']
            )) {
                $subId = $db->lastInsertId();
                $db->prepare(
                    "UPDATE payments SET reference_id = ? WHERE id = ?"
                )->execute([$subId, $payment['id']]);
                http_response_code(200);
                echo json_encode(['message' => 'Subscription activated!']);
            } else {
                http_response_code(503);
                echo json_encode(['message' => 'Subscription activation failed after payment']);
            }
        }
    }
}
