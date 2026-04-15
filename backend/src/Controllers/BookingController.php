<?php

require_once __DIR__ . '/../Models/Booking.php';
require_once __DIR__ . '/../Models/Subscription.php';

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
            http_response_code(200);
            echo json_encode(["message" => "Booking cancelled"]);
        } else {
            http_response_code(503);
            echo json_encode(["message" => "Failed to cancel"]);
        }
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
            $query = "SELECT b.*, c.name as court_name, c.owner_id,
                             u.name as user_name
                      FROM bookings b
                      JOIN courts c ON b.court_id = c.id
                      LEFT JOIN users u ON b.user_id = u.id
                      WHERE c.owner_id = ?
                      ORDER BY b.start_time DESC";
            $stmt = $booking->conn->prepare($query);
            $stmt->execute([(int)$_GET['owner_id']]);
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

        if (
            !empty($data->user_id) &&
            !empty($data->court_id) &&
            !empty($data->start_time) &&
            !empty($data->end_time)
        ) {
            $booking = new Booking();

            if (!$booking->isSlotAvailable($data->court_id, $data->start_time, $data->end_time)) {
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

            $booking->user_id    = (int)$data->user_id;
            $booking->court_id   = (int)$data->court_id;
            $booking->start_time = $data->start_time;
            $booking->end_time   = $data->end_time;
            $booking->type       = $data->type ?? 'hourly';
            $booking->total_price = $data->total_price ?? 0;

            if ($booking->create()) {
                http_response_code(201);
                echo json_encode(["message" => "Booking confirmed.", "id" => (int)$booking->conn->lastInsertId()]);
            } else {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create booking."]);
            }
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Incomplete booking data."]);
        }
    }
}
