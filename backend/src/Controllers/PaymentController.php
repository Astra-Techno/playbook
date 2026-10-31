<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/cashfree.php';
require_once __DIR__ . '/../PeakAccess.php';
require_once __DIR__ . '/../CommerceCheckout.php';
require_once __DIR__ . '/../RefundService.php';
require_once __DIR__ . '/../SlotLock.php';

class PaymentController {

    public function __construct() {
        // Database::migrate owns schema changes. A controller must never drop
        // or alter financial records while serving a customer request.
    }

    /** GET /payments/history — list user's payment records */
    public function history(): void {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $db = Database::getConnection();

        $stmt = $db->prepare(
            "SELECT id, cf_order_id, amount, type, status, reference_id, created_at,
                    (SELECT COALESCE(SUM(r.amount_paise),0)/100 FROM refund_requests r WHERE r.payment_id=payments.id AND r.status='success') AS refunded_amount,
                    (SELECT COALESCE(SUM(r.amount_paise),0)/100 FROM refund_requests r WHERE r.payment_id=payments.id) AS refund_requested_amount,
                    (SELECT r.status FROM refund_requests r WHERE r.payment_id=payments.id ORDER BY r.id DESC LIMIT 1) AS refund_status
             FROM payments
             WHERE user_id = ?
             ORDER BY created_at DESC
             LIMIT 50"
        );
        $stmt->execute([$user_id]);
        $records = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['records' => $records]);
    }

    /** GET /payments/config — frontend uses this to detect demo mode before showing payment UI */
    public function config(): void {
        echo json_encode([
            'demo'        => $this->isDemoMode(),
            'environment' => CASHFREE_ENV,
            'commerce' => CommerceSettings::load(Database::getConnection(), !empty($_GET['court_id']) ? (int)$_GET['court_id'] : null),
        ]);
    }

    public function quote(): void {
        try {
            $data = json_decode(file_get_contents('php://input'), true, 512, JSON_THROW_ON_ERROR);
            $quote = CommerceCheckout::quote(Database::getConnection(), $data['type'] ?? '', $data['payload'] ?? []);
            unset($quote['payload']);
            echo json_encode($quote);
        } catch (InvalidArgumentException | JsonException $e) {
            http_response_code(422); echo json_encode(['message' => $e->getMessage()]);
        }
    }

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

    /**
     * Build split info for Easy Split — returns null if owner has no active vendor.
     */
    private function buildSplit(PDO $db, int $courtId, float $amount): ?array {
        $policy = CommerceSettings::load($db, $courtId);
        if (!$policy['settlement.split_enabled']) return null;
        // Find court owner
        $stmt = $db->prepare("SELECT owner_id FROM courts WHERE id = ?");
        $stmt->execute([$courtId]);
        $ownerId = (int)$stmt->fetchColumn();
        if (!$ownerId) return null;

        // Check if owner has an active vendor profile
        $vStmt = $db->prepare("SELECT cf_vendor_id, commission_pct FROM vendor_profiles WHERE user_id = ? AND cf_vendor_status = 'active'");
        $vStmt->execute([$ownerId]);
        $vendor = $vStmt->fetch(PDO::FETCH_ASSOC);
        if (!$vendor || !$vendor['cf_vendor_id']) return null;

        // Commission: per-vendor override or platform default
        $commPct = $vendor['commission_pct'];
        if ($commPct === null) {
            $commPct = $policy['settlement.commission_percent'];
        }

        $vendorAmount = round($amount * (1 - $commPct / 100), 2);
        if ($vendorAmount <= 0) return null;

        return [
            'vendor_id' => $vendor['cf_vendor_id'],
            'amount'    => $vendorAmount,
        ];
    }

    /** Returns true when real Cashfree credentials are not yet configured */
    private function isDemoMode(): bool {
        return !CASHFREE_APP_ID
            || CASHFREE_APP_ID === 'your_cashfree_app_id'
            || !CASHFREE_SECRET_KEY
            || CASHFREE_SECRET_KEY === 'your_cashfree_secret_key';
    }

    // ── POST /api/payments/create-order ───────────────────────────────────────
    // Body: { amount, type: 'booking'|'subscription', payload: {...} }
    public function createOrder(): void {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $data     = json_decode(file_get_contents('php://input'));
        $amount   = round(floatval($data->amount ?? 0), 2);
        $type     = in_array($data->type ?? '', ['booking', 'subscription'])
                    ? $data->type : 'booking';

        if ($amount <= 0) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid amount']);
            return;
        }

        $db = Database::getConnection();
        try {
            $quote = CommerceCheckout::quote($db, $type, json_decode(json_encode($data->payload ?? new stdClass()), true));
            if (!hash_equals($quote['quote_hash'], (string)($data->quote_hash ?? ''))) {
                http_response_code(409); echo json_encode(['message' => 'Review the latest price and cancellation terms before paying. Update your app if needed.']); return;
            }
        } catch (InvalidArgumentException $e) {
            http_response_code(422); echo json_encode(['message' => $e->getMessage()]); return;
        }
        $amount = $quote['amount'];
        $data->payload = $quote['payload'];
        $quote['snapshot']['gateway'] = ['mode'=>$this->isDemoMode() ? 'demo' : 'cashfree','environment'=>CASHFREE_ENV,'splits'=>[]];
        $snapshot = json_encode($quote['snapshot'], JSON_THROW_ON_ERROR);
        $orderId = ($this->isDemoMode() ? 'demo_' : 'pb_') . $user_id . '_' . bin2hex(random_bytes(10));

        // ── Demo mode: skip Cashfree entirely ────────────────────────────────
        if ($this->isDemoMode()) {
            $stmt = $db->prepare(
                "INSERT INTO payments (user_id, cf_order_id, amount, type, payload, commerce_snapshot, status)
                 VALUES (?, ?, ?, ?, ?, ?, 'demo')"
            );
            $stmt->execute([$user_id, $orderId, $amount, $type, json_encode($data->payload), $snapshot]);
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

        // Build order body
        $orderBody = [
            'order_id'         => $orderId,
            'order_amount'     => $amount,
            'order_currency'   => 'INR',
            'customer_details' => [
                'customer_id'    => 'user_' . $user_id,
                'customer_name'  => $user['name']  ?? 'Customer',
                'customer_phone' => $phone,
            ],
            'order_meta' => ['notify_url' => ''],
        ];

        // Easy Split: if booking for a venue with an active vendor, split payment
        $courtId = (int)($quote['payload']['court_id'] ?? 0);
        if ($courtId && $type === 'booking') {
            $split = $this->buildSplit($db, $courtId, $quote['snapshot']['price']['venue']['total'] / 100);
            if ($split) {
                $orderBody['order_splits'] = [$split];
            }
        } elseif ($courtId && $type === 'subscription') {
            $split = $this->buildSplit($db, $courtId, $quote['snapshot']['price']['venue']['total'] / 100);
            if ($split) {
                $orderBody['order_splits'] = [$split];
            }
        }

        $quote['snapshot']['gateway']['splits'] = $orderBody['order_splits'] ?? [];
        $snapshot = json_encode($quote['snapshot'], JSON_THROW_ON_ERROR);

        // Create order on Cashfree
        $result = $this->cfRequest('POST', '/orders', $orderBody);

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
            "INSERT INTO payments (user_id, cf_order_id, amount, type, payload, commerce_snapshot, status)
             VALUES (?, ?, ?, ?, ?, ?, 'created')"
        );
        $stmt->execute([$user_id, $orderId, $amount, $type, json_encode($data->payload), $snapshot]);

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
        $authUser = Auth::require();
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

        $cfPaymentId = null;
        if (!$isDemo) {
            $attempts = $this->cfRequest('GET', '/orders/' . rawurlencode($orderId) . '/payments');
            foreach (($attempts['data'] ?? []) as $attempt) {
                if (($attempt['payment_status'] ?? '') === 'SUCCESS') { $cfPaymentId = $attempt['cf_payment_id']; break; }
            }
            if (!$cfPaymentId) { http_response_code(502); echo json_encode(['message'=>'Successful payment could not be verified. Try verification again.']); return; }
        }
        $refundQueue = [];
        $verifiedForRecovery = false;

        // ── 2. Load our payment record ────────────────────────────────────────
        $db->beginTransaction();
        try {
        $stmt = $db->prepare(
            "SELECT * FROM payments WHERE cf_order_id = ? AND status IN ('created','demo') FOR UPDATE"
        );
        $stmt->execute([$orderId]);
        $payment = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$payment) {
            http_response_code(404);
            echo json_encode(['message' => 'Payment record not found or already processed']);
            return;
        }

        // Verify the caller owns this payment
        if ((int)$payment['user_id'] !== (int)$authUser['id'] && $authUser['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return;
        }

        if (!$isDemo && (($cfOrder['order_currency'] ?? '') !== 'INR' || (int)round(($cfOrder['order_amount'] ?? -1)*100) !== (int)round($payment['amount']*100))) {
            http_response_code(409); echo json_encode(['message'=>'Payment amount mismatch. Contact support.']); return;
        }
        $verifiedForRecovery = true;
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

            $subCourtId = isset($payload['sub_court_id']) && $payload['sub_court_id'] !== '' && $payload['sub_court_id'] !== null
                ? (int)$payload['sub_court_id'] : null;
            $subCourtRow = null;
            if ($subCourtId) {
                $scStmt = $db->prepare('SELECT * FROM sub_courts WHERE id = ? AND court_id = ?');
                $scStmt->execute([$subCourtId, (int)$payload['court_id']]);
                $subCourtRow = $scStmt->fetch(PDO::FETCH_ASSOC) ?: null;
            }

            // Support both single booking (legacy) and multiple slots
            $slots = isset($payload['slots']) && is_array($payload['slots'])
                ? $payload['slots']
                : [['start_time' => $payload['start_time'], 'end_time' => $payload['end_time']]];

            $slotPrice    = count($slots) > 0 ? round(floatval($payload['total_price']) / count($slots), 2) : floatval($payload['total_price']);
            $bookingIds   = [];
            $takenSlots   = [];
            $missedVenue = 0; $missedFee = 0;

            $commerce = json_decode($payment['commerce_snapshot'] ?? 'null', true);
            $fulfilled = [];
            $courtId = (int)$payload['court_id'];
            $locked = SlotLock::hold($db, $courtId);
            try {
            if ($locked) {
            foreach ($slots as $slotIndex => $slot) {
                // Race-condition guard per slot
                if (!$booking->isSlotAvailable($payload['court_id'], $slot['start_time'], $slot['end_time'], $subCourtId)) {
                    $takenSlots[] = $slot['start_time'];
                    continue;
                }

                // Peak guard per slot (court + optional space override)
                if ($court && PeakAccess::peakMembersOnlyApplies($court, $subCourtRow)) {
                    $peakType = PeakAccess::getPeakType($slot['start_time'], $court);
                    if ($peakType !== null) {
                        $sub    = new Subscription();
                        $active = $sub->getActive((int)$payment['user_id'], (int)$payload['court_id']);
                        if (!$active || !Subscription::coversSlot($active['slot_type'], $peakType)) {
                            $takenSlots[] = $slot['start_time'] . ' (members only)';
                            continue;
                        }
                    }
                }

                $b = new Booking();
                $b->payment_id = (int)$payment['id'];
                $b->user_id      = (int)$payment['user_id']; // trusted — set from token in createOrder
                $b->court_id     = (int)$payload['court_id'];
                $b->sub_court_id = $subCourtId;
                $b->start_time   = $slot['start_time'];
                $b->end_time     = $slot['end_time'];
                $b->type         = $payload['type'] ?? 'hourly';
                $b->total_price  = $commerce ? $slot['total_price'] : $slotPrice;
                $b->commerce_snapshot = $commerce['slots'][$slotIndex] ?? null;

                if ($b->create()) {
                    $bookingIds[] = (int)$db->lastInsertId();
                    $fulfilled[] = $slotIndex;
                }
            }
            }
            } finally {
                if ($locked) SlotLock::release($db, $courtId);
            }

            $unfulfilledRefund = null;
            foreach ($slots as $slotIndex => $slot) {
                if (!in_array($slotIndex, $fulfilled, true) && isset($commerce['slots'][$slotIndex])) {
                    $missedVenue += $commerce['slots'][$slotIndex]['price']['venue']['total'];
                    $missedFee += $commerce['slots'][$slotIndex]['price']['fee']['total'];
                }
            }
            if ($missedVenue + $missedFee > 0) {
                $unfulfilledRefund = (new RefundService($db))->enqueue((int)$payment['id'], null, 'fulfilment:' . $payment['id'], 'unfulfilled_slots', $missedVenue, $missedFee, (int)$authUser['id']);
                $refundQueue[] = (int)$unfulfilledRefund['id'];
            }
            if (empty($bookingIds)) {
                $db->prepare("UPDATE payments SET status = 'refund_pending' WHERE id = ?")->execute([$payment['id']]);
                http_response_code(409);
                echo json_encode(['message' => 'Selected slots could not be booked. Refund has been recorded.' , 'refund'=>$unfulfilledRefund ? RefundService::publicStatus($unfulfilledRefund) : ['status'=>'manual_review']]);
                return;
            }

            // Link first booking to payment record
            $db->prepare("UPDATE payments SET reference_id = ? WHERE id = ?")->execute([$bookingIds[0], $payment['id']]);
            http_response_code(200);
            echo json_encode([
                'message'     => count($bookingIds) . ' slot(s) booked!',
                'booking_ids' => $bookingIds,
                'skipped'     => $takenSlots,
                'refund' => $unfulfilledRefund ? RefundService::publicStatus($unfulfilledRefund) : null,
            ]);

        // ── 3b. Activate Subscription ─────────────────────────────────────────
        } elseif ($payment['type'] === 'subscription') {
            require_once __DIR__ . '/../Models/Subscription.php';
            $sub = new Subscription();

            if ($sub->create(
                (int)$payment['user_id'], // trusted — set from token in createOrder
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
                $snapshot = json_decode($payment['commerce_snapshot'] ?? 'null', true);
                $refund = (new RefundService($db))->enqueue((int)$payment['id'], null, 'fulfilment:' . $payment['id'], 'activation_failed', (int)$snapshot['price']['venue']['total'], (int)$snapshot['price']['fee']['total'], (int)$authUser['id']);
                $refundQueue[] = (int)$refund['id'];
                $db->prepare("UPDATE payments SET status='refund_pending' WHERE id=?")->execute([$payment['id']]);
                echo json_encode(['message'=>'Subscription activation failed. Refund has been recorded.', 'refund'=>RefundService::publicStatus($refund)]);
            }
        }
        } catch (Throwable $e) {
            if ($db->inTransaction()) $db->rollBack();
            $refundQueue = [];
            // All fulfilment writes were rolled back. Reserve a full refund only if
            // another verifier has not fulfilled this payment in the meantime.
            if ($verifiedForRecovery) {
                try {
                    $db->beginTransaction();
                    $recover = $db->prepare("SELECT * FROM payments WHERE id=? AND status IN ('created','demo') FOR UPDATE");
                    $recover->execute([$payment['id']]);
                    if ($original = $recover->fetch(PDO::FETCH_ASSOC)) {
                        $terms = json_decode($original['commerce_snapshot'] ?? 'null', true);
                        if (isset($terms['price'])) {
                            $db->prepare("UPDATE payments SET status='refund_pending', cf_payment_id=? WHERE id=?")->execute([$cfPaymentId,$payment['id']]);
                            $refund = (new RefundService($db))->enqueue((int)$payment['id'],null,'fulfilment:'.$payment['id'],'fulfilment_failed',(int)$terms['price']['venue']['total'],(int)$terms['price']['fee']['total'],(int)$authUser['id']);
                            $refundQueue[] = (int)$refund['id'];
                        }
                    }
                    $db->commit();
                } catch (Throwable $recoveryError) { if ($db->inTransaction()) $db->rollBack(); }
            }
            http_response_code(503);
            echo json_encode(['message'=>'Payment fulfilment failed. Check your payment/refund status or contact support.']);
        } finally {
            if ($db->inTransaction()) $db->commit();
            foreach ($refundQueue as $refundId) {
                try { (new RefundService($db))->process($refundId); } catch (Throwable $e) { /* Cron retries. */ }
            }
        }
    }
}
