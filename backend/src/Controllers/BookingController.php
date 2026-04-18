<?php

require_once __DIR__ . '/../Models/Booking.php';
require_once __DIR__ . '/../Models/Subscription.php';
require_once __DIR__ . '/WaitlistController.php';

class BookingController {

    /**
     * Determine if a given datetime falls within a peak window.
     * Returns 'morning', 'evening', or null.
     */
    private function getPeakType($startDatetime, $court) {
        $time = date('H:i:s', strtotime($startDatetime));
        $mps  = $court['morning_peak_start'] ?? '05:00:00';
        $mpe  = $court['morning_peak_end']   ?? '09:00:00';
        $eps  = $court['evening_peak_start'] ?? '17:00:00';
        $epe  = $court['evening_peak_end']   ?? '21:00:00';

        if ($time >= $mps && $time < $mpe) return 'morning';
        if ($time >= $eps && $time < $epe) return 'evening';
        return null;
    }

    // DELETE /api/bookings/:id  body: { user_id, staff_id? }
    public function cancel($id) {
        $data     = json_decode(file_get_contents("php://input"));
        $user_id  = (int)($data->user_id  ?? 0);
        $staff_id = (int)($data->staff_id ?? 0);
        $booking  = new Booking();

        // Allow cancel if: booking owner OR court staff manager OR court owner
        $row = $booking->conn->prepare("
            SELECT b.*, c.owner_id FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE b.id = ?
        ");
        $row->execute([$id]);
        $b = $row->fetch(PDO::FETCH_ASSOC);

        if (!$b) { http_response_code(404); echo json_encode(["message" => "Booking not found"]); return; }

        $isBookingOwner = $b['user_id'] === $user_id;
        $isCourtOwner   = $b['owner_id'] === $user_id;
        $isStaff        = false;
        if ($staff_id) {
            $sc = $booking->conn->prepare("SELECT id FROM court_staff WHERE court_id = ? AND user_id = ? AND role = 'manager'");
            $sc->execute([$b['court_id'], $staff_id]);
            $isStaff = (bool)$sc->fetch();
        }

        if (!$isBookingOwner && !$isCourtOwner && !$isStaff) {
            http_response_code(403); echo json_encode(["message" => "Not authorised to cancel this booking"]); return;
        }
        if ($b['status'] === 'cancelled') { http_response_code(400); echo json_encode(["message" => "Already cancelled"]); return; }
        if (strtotime($b['start_time']) <= time()) { http_response_code(400); echo json_encode(["message" => "Cannot cancel past bookings"]); return; }

        $upd = $booking->conn->prepare("UPDATE bookings SET status='cancelled' WHERE id=?");
        if ($upd->execute([$id])) {
            // Notify first waitlisted user for this slot
            WaitlistController::notifyNext(
                $booking->conn,
                (int)$b['court_id'],
                $b['sub_court_id'] ? (int)$b['sub_court_id'] : null,
                date('Y-m-d', strtotime($b['start_time'])),
                date('H:i:s', strtotime($b['start_time'])),
                date('H:i:s', strtotime($b['end_time']))
            );
            http_response_code(200);
            echo json_encode(["message" => "Booking cancelled"]);
        } else {
            http_response_code(503);
            echo json_encode(["message" => "Failed to cancel"]);
        }
    }

    // GET /api/bookings/:id  — single booking detail
    public function show($id) {
        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT b.*, c.name AS court_name, c.location AS court_location,
                    sc.name AS space_name, u.name AS user_name
             FROM bookings b
             JOIN courts c ON b.court_id = c.id
             LEFT JOIN sub_courts sc ON b.sub_court_id = sc.id
             LEFT JOIN users u ON b.user_id = u.id
             WHERE b.id = ?"
        );
        $stmt->execute([$id]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$booking) { http_response_code(404); echo json_encode(['message' => 'Booking not found']); return; }
        http_response_code(200);
        echo json_encode(['booking' => $booking]);
    }

    // GET /api/bookings
    // Query params:
    //   user_id   -> bookings made by a player (with court_name join)
    //   court_id + date -> bookings for a court on a specific date (for slot availability)
    //   owner_id  -> all bookings across courts owned by an owner
    public function index() {
        $booking = new Booking();

        if (isset($_GET['user_id'])) {
            $stmt = $booking->readByUser((int)$_GET['user_id']);
        } elseif (isset($_GET['court_id']) && isset($_GET['date'])) {
            $stmt = $booking->readByCourtAndDate((int)$_GET['court_id'], $_GET['date']);
        } elseif (isset($_GET['owner_id'])) {
            $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
            if ($sub_court_id !== null) {
                $query = "SELECT b.*, c.name as court_name, c.owner_id,
                                 u.name as user_name
                          FROM bookings b
                          JOIN courts c ON b.court_id = c.id
                          LEFT JOIN users u ON b.user_id = u.id
                          WHERE c.owner_id = ? AND b.sub_court_id = ?
                          ORDER BY b.start_time DESC";
                $stmt = $booking->conn->prepare($query);
                $stmt->execute([(int)$_GET['owner_id'], $sub_court_id]);
            } else {
                $query = "SELECT b.*, c.name as court_name, c.owner_id,
                                 u.name as user_name
                          FROM bookings b
                          JOIN courts c ON b.court_id = c.id
                          LEFT JOIN users u ON b.user_id = u.id
                          WHERE c.owner_id = ?
                          ORDER BY b.start_time DESC";
                $stmt = $booking->conn->prepare($query);
                $stmt->execute([(int)$_GET['owner_id']]);
            }
        } elseif (isset($_GET['staff_id'])) {
            // Staff: fetch bookings for all courts they manage
            $db      = Database::getConnection();
            $cStmt   = $db->prepare("SELECT court_id FROM court_staff WHERE user_id = ?");
            $cStmt->execute([(int)$_GET['staff_id']]);
            $courtIds = $cStmt->fetchAll(PDO::FETCH_COLUMN);
            if (empty($courtIds)) {
                echo json_encode(["records" => []]); return;
            }
            $in    = implode(',', array_map('intval', $courtIds));
            $query = "SELECT b.*, c.name as court_name, c.owner_id,
                             u.name as user_name
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

        $isWalkIn   = !empty($data->guest_name);
        $hasUser    = !empty($data->user_id);
        $sub_court_id = isset($data->sub_court_id) ? (int)$data->sub_court_id : null;

        if (
            ($hasUser || $isWalkIn) &&
            !empty($data->court_id) &&
            !empty($data->start_time) &&
            !empty($data->end_time)
        ) {
            $booking = new Booking();

            if (!$booking->isSlotAvailable($data->court_id, $data->start_time, $data->end_time, $sub_court_id)) {
                http_response_code(409);
                echo json_encode(["message" => "Time slot not available."]);
                return;
            }

            // Peak hour access check
            $db   = Database::getConnection();
            $stmt = $db->prepare("SELECT * FROM courts WHERE id=?");
            $stmt->execute([(int)$data->court_id]);
            $court = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($court && $court['peak_members_only']) {
                $peakType = $this->getPeakType($data->start_time, $court);
                if ($peakType !== null) {
                    $sub = new Subscription();
                    $active = $sub->getActive((int)$data->user_id, (int)$data->court_id);
                    if (!$active || !Subscription::coversSlot($active['slot_type'], $peakType)) {
                        http_response_code(403);
                        echo json_encode([
                            "message" => "Peak hours are for members only. Please subscribe to book this slot.",
                            "peak_type" => $peakType,
                            "requires_subscription" => true
                        ]);
                        return;
                    }
                }
            }

            // Recalculate total_price server-side using pricing rules (don't trust frontend)
            $serverPrice = $this->calculateBookingPrice(
                (int)$data->court_id,
                $sub_court_id,
                $data->start_time,
                $data->end_time
            );

            $booking->user_id     = $hasUser ? (int)$data->user_id : 0;
            $booking->court_id    = (int)$data->court_id;
            $booking->start_time  = $data->start_time;
            $booking->end_time    = $data->end_time;
            $booking->type        = $data->type ?? 'hourly';
            $booking->total_price = $serverPrice > 0 ? $serverPrice : ($data->total_price ?? 0);
            $booking->sub_court_id = $sub_court_id;
            $booking->guest_name  = $isWalkIn ? trim($data->guest_name) : null;
            $booking->guest_phone = $isWalkIn && !empty($data->guest_phone) ? trim($data->guest_phone) : null;
            $booking->notes       = !empty($data->notes) ? trim($data->notes) : null;

            if ($booking->create()) {
                http_response_code(201);
                $newId = (int)$booking->conn->lastInsertId();
                $msg   = $isWalkIn ? "Walk-in booking created." : "Booking confirmed.";
                echo json_encode(["message" => $msg, "id" => $newId]);
            } else {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create booking."]);
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
    private function calculateBookingPrice(int $court_id, ?int $sub_court_id, string $start, string $end): float
    {
        $db = Database::getConnection();

        // Get base rates
        $cStmt = $db->prepare("SELECT hourly_rate FROM courts WHERE id=?");
        $cStmt->execute([$court_id]);
        $court     = $cStmt->fetch(PDO::FETCH_ASSOC);
        $basePrice = (float)($court['hourly_rate'] ?? 0);

        if ($sub_court_id) {
            $scStmt = $db->prepare("SELECT hourly_rate FROM sub_courts WHERE id=?");
            $scStmt->execute([$sub_court_id]);
            $sc = $scStmt->fetch(PDO::FETCH_ASSOC);
            if ($sc && (float)$sc['hourly_rate'] > 0) $basePrice = (float)$sc['hourly_rate'];
        }

        $startTs = strtotime($start);
        $endTs   = strtotime($end);
        if ($endTs <= $startTs) return $basePrice;

        $date      = date('Y-m-d', $startTs);
        $dow       = (int)date('N', $startTs);
        $isWeekend = $dow >= 6;
        $dayType   = $isWeekend ? 'weekend' : 'weekday';

        // Walk 30-min slots and sum prices
        $total = 0.0;
        $cursor = $startTs;
        while ($cursor < $endTs) {
            $hour = (int)date('H', $cursor);
            $slotDate = date('Y-m-d', $cursor);

            $rule = null;
            // Space-specific rule first
            if ($sub_court_id) {
                $stmt = $db->prepare("
                    SELECT price FROM pricing_rules
                    WHERE court_id=? AND sub_court_id=?
                      AND start_hour<=? AND end_hour>?
                      AND (day_type='all' OR day_type=?)
                      AND (valid_from IS NULL OR valid_from<=?)
                      AND (valid_to IS NULL OR valid_to>=?)
                    ORDER BY priority DESC, id DESC LIMIT 1
                ");
                $stmt->execute([$court_id, $sub_court_id, $hour, $hour, $dayType, $slotDate, $slotDate]);
                $rule = $stmt->fetch(PDO::FETCH_ASSOC);
            }
            // Venue-level fallback
            if (!$rule) {
                $stmt = $db->prepare("
                    SELECT price FROM pricing_rules
                    WHERE court_id=? AND sub_court_id IS NULL
                      AND start_hour<=? AND end_hour>?
                      AND (day_type='all' OR day_type=?)
                      AND (valid_from IS NULL OR valid_from<=?)
                      AND (valid_to IS NULL OR valid_to>=?)
                    ORDER BY priority DESC, id DESC LIMIT 1
                ");
                $stmt->execute([$court_id, $hour, $hour, $dayType, $slotDate, $slotDate]);
                $rule = $stmt->fetch(PDO::FETCH_ASSOC);
            }

            $hourlyRate = $rule ? (float)$rule['price'] : $basePrice;
            $total += $hourlyRate / 2;  // 30-min slot = half an hour
            $cursor += 1800;            // advance 30 minutes
        }
        return round($total, 2);
    }

    // POST /api/bookings/recurring
    // Body: { user_id, court_id, sub_court_id?, start_time, end_time,
    //         recurrence_days: [0,1,2,3,4,5,6],  // JS day-of-week (0=Sun)
    //         recurrence_end_date: "YYYY-MM-DD" }
    // Creates one booking per matching date up to recurrence_end_date (max 12 weeks).
    // Returns { bookings:[ids], skipped:[dates] }
    public function createRecurring() {
        $data = json_decode(file_get_contents("php://input"));
        $user_id      = (int)($data->user_id ?? 0);
        $court_id     = (int)($data->court_id ?? 0);
        $sub_court_id = isset($data->sub_court_id) ? (int)$data->sub_court_id : null;
        $start_time   = $data->start_time ?? ''; // "YYYY-MM-DD HH:MM:SS"
        $end_time     = $data->end_time   ?? '';
        $rec_days     = $data->recurrence_days ?? []; // [0..6]
        $end_date_str = $data->recurrence_end_date ?? '';

        if (!$user_id || !$court_id || !$start_time || !$end_time || empty($rec_days) || !$end_date_str) {
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

        $cursor = $startDateTs;
        while ($cursor <= $limitTs) {
            $dow = (int)date('w', $cursor); // 0=Sun .. 6=Sat
            if (in_array($dow, (array)$rec_days)) {
                $dateStr = date('Y-m-d', $cursor);
                $slotStart = "$dateStr $startH";
                $slotEnd   = "$dateStr $endH";

                if ($booking_model->isSlotAvailable($court_id, $slotStart, $slotEnd, $sub_court_id)) {
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
                } else {
                    $skipped[] = $dateStr;
                }
            }
            $cursor += 86400;
        }

        http_response_code(201);
        echo json_encode(['bookings' => $booked, 'skipped' => $skipped,
                          'message' => count($booked) . ' booking(s) created' . (count($skipped) ? ', ' . count($skipped) . ' date(s) skipped (conflict)' : '')]);
    }
}
