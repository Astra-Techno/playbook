<?php

require_once __DIR__ . '/../Models/Booking.php';
require_once __DIR__ . '/../SlotLock.php';
require_once __DIR__ . '/../Models/Subscription.php';
require_once __DIR__ . '/../PeakAccess.php';
require_once __DIR__ . '/../Push.php';
require_once __DIR__ . '/../CommerceCheckout.php';
require_once __DIR__ . '/../RefundService.php';

class BookingController {

    /**
     * @param array|null $subCourt sub_courts row or null
     * @return array|null ['http'=>int,'json'=>array] when blocked
     */
    private function peakSubscriptionViolation(array $court, ?array $subCourt, string $startTime, int $authId, bool $isWalkIn): ?array
    {
        if ($isWalkIn || !$court) {
            return null;
        }
        if (!PeakAccess::peakMembersOnlyApplies($court, $subCourt)) {
            return null;
        }
        $peakType = PeakAccess::getPeakType($startTime, $court);
        if ($peakType === null) {
            return null;
        }
        $sub    = new Subscription();
        $active = $sub->getActive($authId, (int)$court['id']);
        if ($active && Subscription::coversSlot($active['slot_type'], $peakType)) {
            return null;
        }
        return [
            'http' => 403,
            'json' => [
                'message'                 => 'Peak hours are for members only. Please subscribe to book this slot.',
                'peak_type'               => $peakType,
                'requires_subscription'   => true,
            ],
        ];
    }

    // DELETE /api/bookings/:id
    public function cancel($id) {
        $authUser = Auth::user();
        $user_id  = (int)$authUser['id']; // always from token — never trust body
        $booking  = new Booking();

        // Allow cancel if: booking owner OR court owner OR staff manager OR admin
        $row = $booking->conn->prepare("
            SELECT b.*, c.owner_id FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE b.id = ?
        ");
        $row->execute([$id]);
        $b = $row->fetch(PDO::FETCH_ASSOC);

        if (!$b) { http_response_code(404); echo json_encode(["message" => "Booking not found"]); return; }

        $isBookingOwner = (int)$b['user_id'] === $user_id;
        $isCourtOwner   = (int)$b['owner_id'] === $user_id;
        $isAdmin        = $authUser['role'] === 'admin';
        $sc = $booking->conn->prepare("SELECT id FROM court_staff WHERE court_id = ? AND user_id = ? AND role = 'manager'");
        $sc->execute([$b['court_id'], $user_id]);
        $isStaff = (bool)$sc->fetch();

        if (!$isBookingOwner && !$isCourtOwner && !$isStaff && !$isAdmin) {
            http_response_code(403); echo json_encode(["message" => "Not authorised to cancel this booking"]); return;
        }
        if ($b['status'] === 'cancelled') { http_response_code(400); echo json_encode(["message" => "Already cancelled"]); return; }
        if ((new DateTimeImmutable($b['start_time'], new DateTimeZone('Asia/Kolkata')))->getTimestamp() <= time()) { http_response_code(400); echo json_encode(["message" => "Cannot cancel past bookings"]); return; }

        $snapshot = json_decode($b['commerce_snapshot'] ?? 'null', true);
        $policy = $snapshot['policy'] ?? CommerceSettings::load($booking->conn, (int)$b['court_id']);
        $venueCancelled = !$isBookingOwner && ($isCourtOwner || $isStaff || $isAdmin);
        if ($snapshot && !$venueCancelled && !$policy['cancellation.enabled']) {
            http_response_code(422); echo json_encode(['message' => 'Customer cancellation is disabled for this booking']); return;
        }
        $start = new DateTimeImmutable($b['start_time'], new DateTimeZone('Asia/Kolkata'));
        $refund = $snapshot ? CommerceSettings::refund($snapshot, ($start->getTimestamp() - time()) / 3600, $venueCancelled) : null;
        $booking->conn->beginTransaction();
        try {
            $upd = $booking->conn->prepare("UPDATE bookings SET status='cancelled' WHERE id=? AND status <> 'cancelled'");
            $upd->execute([$id]);
            if ($upd->rowCount() !== 1) {
                $booking->conn->rollBack(); http_response_code(409); echo json_encode(['message' => 'Booking already cancelled']); return;
            }
            $refundId = null;
            $automatic = null;
            if ($refund === null || $refund['total'] > 0) {
                $booking->conn->prepare("INSERT INTO booking_refunds (booking_id, amount_paise, breakdown, requested_by) VALUES (?, ?, ?, ?)")
                    ->execute([$id, $refund['total'] ?? 0, json_encode($refund ?? ['note' => 'Legacy booking: review original payment and terms manually']), $user_id]);
                $refundId = (int)$booking->conn->lastInsertId();
                if ($refund && !empty($b['payment_id'])) {
                    $automatic = (new RefundService($booking->conn))->enqueue((int)$b['payment_id'], (int)$id, 'cancel:' . $id, 'cancellation', (int)$refund['venue'], (int)$refund['fee'], $user_id);
                    $booking->conn->prepare('UPDATE booking_refunds SET refund_request_id=? WHERE id=?')->execute([$automatic['id'], $refundId]);
                }
            }
            $booking->conn->commit();
        } catch (Throwable $e) {
            if ($booking->conn->inTransaction()) $booking->conn->rollBack();
            throw $e;
        }
        // Network failures cannot undo a committed cancellation; cron retries the durable outbox.
        if ($automatic && $automatic['status'] === 'queued') {
            try { $automatic = (new RefundService($booking->conn))->process((int)$automatic['id']); }
            catch (Throwable $e) { /* The queued request remains recoverable. */ }
        }
        http_response_code(200);
        $result = $automatic ? RefundService::publicStatus($automatic) : ['id'=>$refundId, 'status'=>$refundId ? 'manual_review' : 'not_due', 'amount'=>$refund ? $refund['total']/100 : null];
        $result['expected_business_days'] = $policy['refund.expected_days'];
        echo json_encode(['message'=>'Booking cancelled.' . ($refundId ? ' Refund status: ' . str_replace('_',' ',$result['status']) . '.' : ''), 'refund'=>$result]);

        // Notify venue owner when a player cancels
        if ($isBookingOwner && !$isCourtOwner) {
            $db = Database::getConnection();
            $cStmt = $db->prepare("SELECT name FROM courts WHERE id = ?");
            $cStmt->execute([$b['court_id']]);
            $courtRow = $cStmt->fetch(PDO::FETCH_ASSOC);
            $playerName = $authUser['name'] ?? 'A player';
            $courtName  = $courtRow['name'] ?? 'your venue';
            $dateStr    = date('D, d M', strtotime($b['start_time']));

            Push::sendToUser(
                (int)$b['owner_id'],
                'Booking Cancelled',
                "{$playerName} cancelled their booking at {$courtName} on {$dateStr}",
                ['type' => 'cancellation', 'court_id' => (string)$b['court_id']]
            );

            try {
                $db->prepare(
                    "INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?,?,?,?,?)"
                )->execute([
                    (int)$b['owner_id'],
                    'cancellation',
                    'Booking Cancelled',
                    "{$playerName} cancelled their booking at {$courtName} on {$dateStr}",
                    (int)$b['court_id']
                ]);
            } catch (\PDOException $e) {}
        }

        // Notify player when owner/staff cancels their booking
        if ($isCourtOwner && !$isBookingOwner && (int)$b['user_id'] > 0) {
            $db = Database::getConnection();
            $cStmt = $db->prepare("SELECT name FROM courts WHERE id = ?");
            $cStmt->execute([$b['court_id']]);
            $courtRow = $cStmt->fetch(PDO::FETCH_ASSOC);
            $courtName = $courtRow['name'] ?? 'a venue';
            $dateStr   = date('D, d M', strtotime($b['start_time']));

            Push::sendToUser(
                (int)$b['user_id'],
                'Booking Cancelled',
                "Your booking at {$courtName} on {$dateStr} was cancelled by the venue",
                ['type' => 'cancellation', 'court_id' => (string)$b['court_id']]
            );

            try {
                $db->prepare(
                    "INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?,?,?,?,?)"
                )->execute([
                    (int)$b['user_id'],
                    'cancellation',
                    'Booking Cancelled',
                    "Your booking at {$courtName} on {$dateStr} was cancelled by the venue",
                    (int)$b['court_id']
                ]);
            } catch (\PDOException $e) {}
        }
    }

    // PUT /api/bookings/:id  { start_time, end_time }
    // Moves a confirmed booking. The price stored on the row stays as it is.
    public function reschedule($id) {
        $authUser = Auth::user();
        $userId = (int)$authUser['id'];
        $data = json_decode(file_get_contents('php://input'));
        $start = trim((string)($data->start_time ?? ''));
        $end = trim((string)($data->end_time ?? ''));
        $stamp = '/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/';
        if (!preg_match($stamp, $start) || !preg_match($stamp, $end) || strtotime($end) <= strtotime($start)) {
            http_response_code(400);
            echo json_encode(['message' => 'Provide a start and a later end as YYYY-MM-DD HH:MM:SS.']);
            return;
        }

        $db = Database::getConnection();
        $row = $db->prepare("SELECT b.*, c.owner_id FROM bookings b JOIN courts c ON c.id = b.court_id WHERE b.id = ?");
        $row->execute([$id]);
        $booking = $row->fetch(PDO::FETCH_ASSOC);
        if (!$booking) { http_response_code(404); echo json_encode(['message' => 'Booking not found']); return; }

        $isBookingOwner = (int)$booking['user_id'] === $userId;
        $isCourtOwner = (int)$booking['owner_id'] === $userId;
        $isAdmin = ($authUser['role'] ?? '') === 'admin';
        $staff = $db->prepare("SELECT id FROM court_staff WHERE court_id = ? AND user_id = ? AND role = 'manager'");
        $staff->execute([$booking['court_id'], $userId]);
        $isStaff = (bool)$staff->fetch();
        if (!$isBookingOwner && !$isCourtOwner && !$isStaff && !$isAdmin) {
            http_response_code(403);
            echo json_encode(['message' => 'Not authorised to move this booking']);
            return;
        }
        if ($booking['status'] !== 'confirmed') {
            http_response_code(400);
            echo json_encode(['message' => 'Only a confirmed booking can be moved.']);
            return;
        }
        $now = new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata'));
        $currentStart = new DateTimeImmutable($booking['start_time'], new DateTimeZone('Asia/Kolkata'));
        $nextStart = new DateTimeImmutable($start, new DateTimeZone('Asia/Kolkata'));
        if ($currentStart <= $now || $nextStart <= $now) {
            http_response_code(400);
            echo json_encode(['message' => 'Choose a future time. A booking that has started stays where it is.']);
            return;
        }

        $courtId = (int)$booking['court_id'];
        $subCourtId = $booking['sub_court_id'] !== null && $booking['sub_court_id'] !== '' ? (int)$booking['sub_court_id'] : null;
        if (!SlotLock::hold($db, $courtId)) {
            http_response_code(409);
            echo json_encode(['message' => 'This time is being booked. Try again.']);
            return;
        }
        try {
            if ($booking['start_time'] === $start && $booking['end_time'] === $end) {
                http_response_code(200);
                echo json_encode([
                    'message' => 'Booking moved. The price already stored on it is unchanged.',
                    'start_time' => $start,
                    'end_time' => $end,
                    'total_price' => $booking['total_price'],
                ]);
                return;
            }
            $model = new Booking();
            if (!$model->isSlotAvailable($courtId, $start, $end, $subCourtId, (int)$id)) {
                http_response_code(409);
                echo json_encode(['message' => 'That time is not available.']);
                return;
            }
            $upd = $db->prepare("UPDATE bookings SET start_time = ?, end_time = ? WHERE id = ? AND status = 'confirmed'");
            $upd->execute([$start, $end, $id]);
            if ($upd->rowCount() !== 1) {
                http_response_code(409);
                echo json_encode(['message' => 'This booking could not be moved.']);
                return;
            }
            http_response_code(200);
            echo json_encode([
                'message' => 'Booking moved. The price already stored on it is unchanged.',
                'start_time' => $start,
                'end_time' => $end,
                'total_price' => $booking['total_price'],
            ]);
        } finally {
            SlotLock::release($db, $courtId);
        }
    }

    // GET /api/bookings/:id  — single booking detail
    public function show($id) {
        $authUser = Auth::user();
        $authId   = (int)$authUser['id'];
        $db       = Database::getConnection();
        $stmt     = $db->prepare(
            "SELECT b.*, c.name AS court_name, c.location AS court_location,
                    c.owner_id, sc.name AS space_name, u.name AS user_name
             FROM bookings b
             JOIN courts c ON b.court_id = c.id
             LEFT JOIN sub_courts sc ON b.sub_court_id = sc.id
             LEFT JOIN users u ON b.user_id = u.id
             WHERE b.id = ?"
        );
        $stmt->execute([$id]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$booking) { http_response_code(404); echo json_encode(['message' => 'Booking not found']); return; }

        // Only booking owner, court owner, or admin can view
        $canView = (int)$booking['user_id'] === $authId
                || (int)$booking['owner_id'] === $authId
                || $authUser['role'] === 'admin';
        if (!$canView) {
            $staff = $db->prepare("SELECT id FROM court_staff WHERE court_id = ? AND user_id = ? AND role = 'manager'");
            $staff->execute([(int)$booking['court_id'], $authId]);
            $canView = (bool)$staff->fetch();
        }
        if (!$canView) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }

        unset($booking['owner_id']);
        http_response_code(200);
        echo json_encode(['booking' => $booking]);
    }

    // GET /api/bookings
    // Query params (user_id/owner_id/staff_id are ignored — always uses token):
    //   user_id   -> player's own bookings
    //   court_id + date -> slot availability (public)
    //   owner_id  -> owner's courts bookings
    //   staff_id  -> managed courts bookings
    public function index() {
        $authUser = Auth::user();
        $authId   = (int)$authUser['id'];
        $booking  = new Booking();

        if (isset($_GET['user_id'])) {
            // Always use token's user — ignoring query param prevents user spoofing
            $stmt = $booking->readByUser($authId);
        } elseif (isset($_GET['court_id']) && isset($_GET['date'])) {
            // Slot availability — no user filter needed
            $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
            $stmt = $booking->readByCourtAndDate((int)$_GET['court_id'], $_GET['date'], $sub_court_id);
        } elseif (isset($_GET['owner_id'])) {
            // Owner views their own courts' bookings — use token's user
            $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
            if ($sub_court_id !== null) {
                $query = "SELECT b.*, c.name as court_name, c.owner_id, u.name as user_name
                          FROM bookings b
                          JOIN courts c ON b.court_id = c.id
                          LEFT JOIN users u ON b.user_id = u.id
                          WHERE c.owner_id = ? AND b.sub_court_id = ?
                          ORDER BY b.start_time DESC";
                $stmt = $booking->conn->prepare($query);
                $stmt->execute([$authId, $sub_court_id]);
            } else {
                $query = "SELECT b.*, c.name as court_name, c.owner_id, u.name as user_name
                          FROM bookings b
                          JOIN courts c ON b.court_id = c.id
                          LEFT JOIN users u ON b.user_id = u.id
                          WHERE c.owner_id = ?
                          ORDER BY b.start_time DESC";
                $stmt = $booking->conn->prepare($query);
                $stmt->execute([$authId]);
            }
        } elseif (isset($_GET['staff_id'])) {
            // Staff: fetch bookings for all courts managed by token's user
            $db      = Database::getConnection();
            $cStmt   = $db->prepare("SELECT court_id FROM court_staff WHERE user_id = ?");
            $cStmt->execute([$authId]);
            $courtIds = $cStmt->fetchAll(PDO::FETCH_COLUMN);
            if (empty($courtIds)) {
                echo json_encode(["records" => []]); return;
            }
            $in    = implode(',', array_map('intval', $courtIds));
            $query = "SELECT b.*, c.name as court_name, c.owner_id, u.name as user_name
                      FROM bookings b
                      JOIN courts c ON b.court_id = c.id
                      LEFT JOIN users u ON b.user_id = u.id
                      WHERE c.id IN ({$in})
                      ORDER BY b.start_time DESC";
            $stmt  = $db->prepare($query);
            $stmt->execute();
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Provide user_id, or court_id+date, or owner_id, or staff_id."]);
            return;
        }

        $records = $stmt->fetchAll(PDO::FETCH_ASSOC);
        http_response_code(200);
        echo json_encode(["records" => $records]);
    }

    // GET /api/bookings/busy-days?court_id=X&month=YYYY-MM
    // Returns array of days (1–31) that have at least one confirmed booking
    public function busyDays() {
        $court_id = (int)($_GET['court_id'] ?? 0);
        $month    = $_GET['month'] ?? date('Y-m');
        if (!$court_id) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id required']);
            return;
        }
        // Validate month format
        if (!preg_match('/^\d{4}-\d{2}$/', $month)) $month = date('Y-m');
        $start = $month . '-01';
        $end   = date('Y-m-t', strtotime($start)); // last day of month

        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT DISTINCT DAY(start_time) AS day
             FROM bookings
             WHERE court_id = ? AND status != 'cancelled'
               AND DATE(start_time) BETWEEN ? AND ?
             ORDER BY day"
        );
        $stmt->execute([$court_id, $start, $end]);
        $days = $stmt->fetchAll(PDO::FETCH_COLUMN);
        http_response_code(200);
        echo json_encode(['busy_days' => array_map('intval', $days)]);
    }

    // POST /api/bookings
    public function create() {
        $data = json_decode(file_get_contents("php://input"));

        $authUser     = Auth::user();
        $isWalkIn     = !empty($data->guest_name);
        $authId       = $authUser ? (int)$authUser['id'] : 0;
        $sub_court_id = isset($data->sub_court_id) ? (int)$data->sub_court_id : null;

        // Walk-in bookings (created by owner/staff on behalf of guest) don't need a logged-in user_id
        // Regular bookings require an authenticated user
        if (!$isWalkIn && !$authId) {
            http_response_code(401);
            echo json_encode(["message" => "Authentication required"]);
            return;
        }

        if (
            !empty($data->court_id) &&
            !empty($data->start_time) &&
            !empty($data->end_time)
        ) {
            $booking = new Booking();
            $db = Database::getConnection();
            $courtId = (int)$data->court_id;
            $stmt = $db->prepare("SELECT * FROM courts WHERE id=?");
            $stmt->execute([$courtId]);
            $court = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($isWalkIn) {
                $staff = $db->prepare("SELECT id FROM court_staff WHERE court_id = ? AND user_id = ? AND role = 'manager'");
                $staff->execute([$courtId, $authId]);
                if (!$court || ((int)$court['owner_id'] !== $authId && ($authUser['role'] ?? '') !== 'admin' && !$staff->fetchColumn())) {
                    http_response_code(403); echo json_encode(['message' => 'Only the venue owner or manager can record walk-ins']); return;
                }
            }

            if (!SlotLock::hold($db, $courtId)) {
                http_response_code(409);
                echo json_encode(['message' => 'This time is being booked. Try again.']);
                return;
            }
            try {
            if (!$booking->isSlotAvailable($data->court_id, $data->start_time, $data->end_time, $sub_court_id)) {
                http_response_code(409);
                echo json_encode(["message" => "Time slot not available."]);
                return;
            }

            $subCourt = null;
            if ($sub_court_id) {
                $scStmt = $db->prepare("SELECT * FROM sub_courts WHERE id = ? AND court_id = ?");
                $scStmt->execute([$sub_court_id, $courtId]);
                $subCourt = $scStmt->fetch(PDO::FETCH_ASSOC) ?: null;
            }

            $peakErr = $this->peakSubscriptionViolation($court ?: [], $subCourt, $data->start_time, $authId, $isWalkIn);
            if ($peakErr) {
                http_response_code($peakErr['http']);
                echo json_encode($peakErr['json']);
                return;
            }

            // Recalculate total_price server-side using pricing rules (don't trust frontend)
            $serverPrice = $this->calculateBookingPrice(
                $courtId,
                $sub_court_id,
                $data->start_time,
                $data->end_time
            );

            $booking->user_id     = $isWalkIn ? 0 : $authId;
            $booking->court_id    = $courtId;
            $booking->start_time  = $data->start_time;
            $booking->end_time    = $data->end_time;
            $booking->type        = $data->type ?? 'hourly';
            $booking->total_price = $serverPrice > 0 ? $serverPrice : ($data->total_price ?? 0);
            if (!$isWalkIn) {
                $policy = CommerceSettings::load($db, $courtId);
                try { CommerceCheckout::validateTime($data->start_time, $data->end_time, $policy); }
                catch (InvalidArgumentException $e) { http_response_code(422); echo json_encode(['message' => $e->getMessage()]); return; }
                if (!$policy['checkout.enabled'] || $booking->total_price > 0 || $policy['fee.enabled'] || $policy['venue.gst_registered']) {
                    http_response_code(409); echo json_encode(['message' => 'Use payment checkout to review the configured pricing and taxes']); return;
                }
                $booking->commerce_snapshot = ['version' => 1, 'policy' => $policy, 'price' => CommerceSettings::price((int)round($booking->total_price * 100), $policy)];
            }
            $booking->sub_court_id = $sub_court_id;
            $booking->guest_name  = $isWalkIn ? trim($data->guest_name) : null;
            $booking->guest_phone = $isWalkIn && !empty($data->guest_phone) ? trim($data->guest_phone) : null;
            $booking->notes       = !empty($data->notes) ? trim($data->notes) : null;

            if ($booking->create()) {
                http_response_code(201);
                $newId = (int)$booking->conn->lastInsertId();
                $msg   = $isWalkIn ? "Walk-in booking created." : "Booking confirmed.";
                echo json_encode(["message" => $msg, "id" => $newId]);

                // Push: notify court owner of new booking
                if (!$isWalkIn && $court && !empty($court['owner_id'])) {
                    $playerName = $authUser['name'] ?? 'Someone';
                    $courtName  = $court['name']    ?? 'your court';
                    $dateStr    = date('D, d M', strtotime($data->start_time));
                    Push::sendToUser(
                        (int)$court['owner_id'],
                        'New Booking',
                        "{$playerName} booked {$courtName} on {$dateStr}",
                        ['type' => 'booking', 'booking_id' => (string)$newId, 'court_id' => (string)$court['id']]
                    );

                    // In-app notification for venue owner
                    try {
                        $db->prepare(
                            "INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?,?,?,?,?)"
                        )->execute([
                            (int)$court['owner_id'],
                            'booking',
                            'New Booking',
                            "{$playerName} booked {$courtName} on {$dateStr}",
                            (int)$court['id']
                        ]);
                    } catch (\PDOException $e) {}
                }


            } else {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create booking."]);
            }
            } finally {
                SlotLock::release($db, $courtId);
            }
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Incomplete booking data."]);
        }
    }

    /**
     * Calculate booking price using pricing rules (30-min slots × hourly rate / 2).
     * Falls back to court/space base hourly_rate if no rules match.
     */
    public function calculateBookingPrice(int $court_id, ?int $sub_court_id, string $start, string $end): float
    {
        $db = Database::getConnection();

        $cStmt = $db->prepare("SELECT hourly_rate FROM courts WHERE id=?");
        $cStmt->execute([$court_id]);
        $court = $cStmt->fetch(PDO::FETCH_ASSOC);
        $facilityRate = null;
        if ($sub_court_id) {
            $scStmt = $db->prepare("SELECT hourly_rate FROM sub_courts WHERE id=?");
            $scStmt->execute([$sub_court_id]);
            $sc = $scStmt->fetch(PDO::FETCH_ASSOC);
            $facilityRate = $sc['hourly_rate'] ?? null;
        }
        $basePrice = ScheduleRules::baseRate((float)($court['hourly_rate'] ?? 0), $facilityRate);
        $loaded = $db->prepare("SELECT * FROM pricing_rules WHERE court_id=?");
        $loaded->execute([$court_id]);
        $split = ScheduleRules::splitRules($loaded->fetchAll(PDO::FETCH_ASSOC), $sub_court_id);
        return ScheduleRules::quote($start, $end, $basePrice, $split['facility'], $split['venue']);
    }

    // POST /api/bookings/recurring
    // Body: { court_id, sub_court_id?, start_time, end_time,
    //         recurrence_days: [0,1,2,3,4,5,6],  // JS day-of-week (0=Sun)
    //         recurrence_end_date: "YYYY-MM-DD" }
    // Creates one booking per matching date up to recurrence_end_date (max 12 weeks).
    // Returns { bookings:[ids], skipped:[dates] }
    public function createRecurring() {
        $authUser     = Auth::require(); // must be authenticated
        $user_id      = (int)$authUser['id'];
        $data         = json_decode(file_get_contents("php://input"));
        $court_id     = (int)($data->court_id ?? 0);
        $sub_court_id = isset($data->sub_court_id) ? (int)$data->sub_court_id : null;
        $start_time   = $data->start_time ?? ''; // "YYYY-MM-DD HH:MM:SS"
        $end_time     = $data->end_time   ?? '';
        $rec_days     = $data->recurrence_days ?? []; // [0..6]
        $end_date_str = $data->recurrence_end_date ?? '';

        if (!$court_id || !$start_time || !$end_time || empty($rec_days) || !$end_date_str) {
            http_response_code(400); echo json_encode(['message' => 'Missing required fields']); return;
        }

        $startTs  = strtotime($start_time);
        $endTs    = strtotime($end_time);
        $limitTs  = strtotime($end_date_str . ' 23:59:59');
        $maxLimit = strtotime('+12 weeks', $startTs);
        if ($limitTs > $maxLimit) $limitTs = $maxLimit;

        $startDateTs = mktime(0,0,0, date('n',$startTs), date('j',$startTs), date('Y',$startTs));
        $startH      = date('H:i:s', $startTs);
        $endH        = date('H:i:s', $endTs);

        $booking_model = new Booking();
        $booked  = [];
        $skipped = [];

        $dbPeak   = Database::getConnection();
        $courtRow = $dbPeak->prepare('SELECT * FROM courts WHERE id = ?');
        $courtRow->execute([$court_id]);
        $court = $courtRow->fetch(PDO::FETCH_ASSOC) ?: [];
        $subCourt = null;
        if ($sub_court_id) {
            $scStmt = $dbPeak->prepare('SELECT * FROM sub_courts WHERE id = ? AND court_id = ?');
            $scStmt->execute([$sub_court_id, $court_id]);
            $subCourt = $scStmt->fetch(PDO::FETCH_ASSOC) ?: null;
        }

        if (!SlotLock::hold($dbPeak, $court_id)) {
            http_response_code(409);
            echo json_encode(['message' => 'This time is being booked. Try again.']);
            return;
        }
        try {
        $cursor = $startDateTs;
        while ($cursor <= $limitTs) {
            $dow = (int)date('w', $cursor); // 0=Sun .. 6=Sat
            if (in_array($dow, (array)$rec_days)) {
                $dateStr = date('Y-m-d', $cursor);
                $slotStart = "$dateStr $startH";
                $slotEnd   = "$dateStr $endH";

                if (!$booking_model->isSlotAvailable($court_id, $slotStart, $slotEnd, $sub_court_id)) {
                    $skipped[] = $dateStr;
                } elseif ($this->peakSubscriptionViolation($court, $subCourt, $slotStart, $user_id, false)) {
                    $skipped[] = $dateStr;
                } else {
                    $price = $this->calculateBookingPrice($court_id, $sub_court_id, $slotStart, $slotEnd);
                    $booking_model->user_id      = $user_id;
                    $booking_model->court_id     = $court_id;
                    $booking_model->sub_court_id = $sub_court_id;
                    $booking_model->start_time   = $slotStart;
                    $booking_model->end_time     = $slotEnd;
                    $booking_model->type         = 'hourly';
                    $booking_model->total_price  = $price > 0 ? $price : 0;
                    $booking_model->guest_name   = null;
                    $booking_model->guest_phone  = null;
                    $booking_model->notes        = 'Recurring booking';
                    if ($booking_model->create()) {
                        $booked[] = (int)$booking_model->conn->lastInsertId();
                    }
                }
            }
            $cursor += 86400;
        }
        } finally {
            SlotLock::release($dbPeak, $court_id);
        }

        http_response_code(201);
        echo json_encode(['bookings' => $booked, 'skipped' => $skipped,
                          'message' => count($booked) . ' booking(s) created' . (count($skipped) ? ', ' . count($skipped) . ' date(s) skipped (conflict)' : '')]);
    }

}
