<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../ScheduleRules.php';

class Booking {
    public $conn;
    private $table_name = "bookings";

    public $id;
    public $user_id;
    public $court_id;
    public $sub_court_id;
    public $start_time;
    public $end_time;
    public $type;
    public $total_price;
    public $status;
    public $payment_status;
    public $guest_name;
    public $guest_phone;
    public $notes;
    public $commerce_snapshot;
    public $payment_id;

    public function __construct() {
        $this->conn = Database::getConnection();
    }

    // Create booking
    public function create() {
        $query = "INSERT INTO " . $this->table_name . "
                  SET user_id=:user_id, court_id=:court_id, start_time=:start_time,
                      end_time=:end_time, type=:type, total_price=:total_price,
                      status='confirmed', payment_status='paid',
                      sub_court_id=:sub_court_id, guest_name=:guest_name,
                      guest_phone=:guest_phone, notes=:notes, commerce_snapshot=:commerce_snapshot, payment_id=:payment_id";

        $stmt = $this->conn->prepare($query);

        $this->start_time  = htmlspecialchars(strip_tags($this->start_time));
        $this->end_time    = htmlspecialchars(strip_tags($this->end_time));
        $this->type        = htmlspecialchars(strip_tags($this->type));
        $this->total_price = htmlspecialchars(strip_tags($this->total_price));

        $stmt->bindParam(":user_id",      $this->user_id);
        $stmt->bindParam(":court_id",     $this->court_id);
        $stmt->bindParam(":start_time",   $this->start_time);
        $stmt->bindParam(":end_time",     $this->end_time);
        $stmt->bindParam(":type",         $this->type);
        $stmt->bindParam(":total_price",  $this->total_price);
        $stmt->bindParam(":sub_court_id", $this->sub_court_id);
        $stmt->bindParam(":guest_name",   $this->guest_name);
        $stmt->bindParam(":guest_phone",  $this->guest_phone);
        $stmt->bindParam(":notes",        $this->notes);
        $snapshotJson = $this->commerce_snapshot ? json_encode($this->commerce_snapshot, JSON_THROW_ON_ERROR) : null;
        $stmt->bindValue(':commerce_snapshot', $snapshotJson);
        $stmt->bindValue(':payment_id', $this->payment_id);

        if ($stmt->execute()) {
            return true;
        }
        return false;
    }

    public function readByUser($user_id) {
        $query = "SELECT b.*, c.name as court_name, c.owner_id," .
                 " u.name as owner_name, COALESCE(r.status,br.status) AS refund_status, COALESCE(r.amount_paise,br.amount_paise) AS refund_amount_paise, r.refund_id AS refund_reference" .
                 " FROM " . $this->table_name . " b" .
                 " JOIN courts c ON b.court_id = c.id" .
                 " LEFT JOIN users u ON c.owner_id = u.id" .
                 " LEFT JOIN booking_refunds br ON br.booking_id=b.id LEFT JOIN refund_requests r ON r.id=br.refund_request_id" .
                 " WHERE b.user_id = ?" .
                 " ORDER BY b.start_time DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $user_id);
        $stmt->execute();
        return $stmt;
    }
    /**
     * Return bookings for a specific court on a specific date.
     */
    public function readByCourtAndDate($court_id, $date, $sub_court_id = null) {
        $query = "SELECT * FROM " . $this->table_name .
                 " WHERE court_id = :court_id" .
                 " AND DATE(start_time) = :date" .
                 " AND status = 'confirmed'";
        if ($sub_court_id !== null) {
            $query .= " AND sub_court_id = :sub_court_id";
        }
        $query .= " ORDER BY start_time";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':court_id', $court_id);
        $stmt->bindParam(':date', $date);
        if ($sub_court_id !== null) {
            $stmt->bindParam(':sub_court_id', $sub_court_id);
        }
        $stmt->execute();
        return $stmt;
    }

    /**
     * Check if the desired time slot is available.
     * Checks both confirmed bookings and blocked_slots.
     * If sub_court_id is provided, only checks that sub-court's bookings.
     */
    public function isSlotAvailable($court_id, $start_time, $end_time, $sub_court_id = null, $ignore_booking_id = null) {
        $ignoreSql = $ignore_booking_id ? ' AND id <> :ignore_id' : '';
        // Check bookings
        if ($sub_court_id !== null) {
            // Look up booking_mode and capacity for this space
            $scStmt = $this->conn->prepare("SELECT booking_mode, capacity FROM sub_courts WHERE id = ?");
            $scStmt->execute([$sub_court_id]);
            $sc = $scStmt->fetch(PDO::FETCH_ASSOC);
            $booking_mode = $sc ? ($sc['booking_mode'] ?? 'exclusive') : 'exclusive';
            $capacity     = $sc ? max(1, (int)($sc['capacity'] ?? 1)) : 1;

            $query = "SELECT COUNT(*) as cnt FROM " . $this->table_name .
                     " WHERE court_id = :court_id AND sub_court_id = :sub_court_id" .
                     " AND (start_time < :end_time AND end_time > :start_time)" .
                     " AND status = 'confirmed'" . $ignoreSql;
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(':court_id',    $court_id);
            $stmt->bindParam(':sub_court_id',$sub_court_id);
            $stmt->bindParam(':start_time',  $start_time);
            $stmt->bindParam(':end_time',    $end_time);
            if ($ignore_booking_id) {
                $stmt->bindValue(':ignore_id', (int)$ignore_booking_id, PDO::PARAM_INT);
            }
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!ScheduleRules::capacityAllows($booking_mode, (int)$row['cnt'], $capacity)) {
                return false;
            }
        } else {
            $query = "SELECT COUNT(*) as cnt FROM " . $this->table_name .
                     " WHERE court_id = :court_id" .
                     " AND (start_time < :end_time AND end_time > :start_time)" .
                     " AND status = 'confirmed'" . $ignoreSql;
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(':court_id',   $court_id);
            $stmt->bindParam(':start_time', $start_time);
            $stmt->bindParam(':end_time',   $end_time);
            if ($ignore_booking_id) {
                $stmt->bindValue(':ignore_id', (int)$ignore_booking_id, PDO::PARAM_INT);
            }
            $stmt->execute();
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!ScheduleRules::capacityAllows('exclusive', (int)$row['cnt'], 1)) {
                return false;
            }
        }

        // One-off blocked_slots (repeat_annually = 0): venue-wide or space-specific.
        if ($sub_court_id !== null) {
            $blk = $this->conn->prepare(
                "SELECT COUNT(*) as cnt FROM blocked_slots
                 WHERE court_id = ?
                   AND (sub_court_id IS NULL OR sub_court_id = ?)
                   AND COALESCE(repeat_annually, 0) = 0
                   AND (start_time < ? AND end_time > ?)"
            );
            $blk->execute([$court_id, $sub_court_id, $end_time, $start_time]);
        } else {
            $blk = $this->conn->prepare(
                "SELECT COUNT(*) as cnt FROM blocked_slots
                 WHERE court_id = ?
                   AND sub_court_id IS NULL
                   AND COALESCE(repeat_annually, 0) = 0
                   AND (start_time < ? AND end_time > ?)"
            );
            $blk->execute([$court_id, $end_time, $start_time]);
        }
        $blkRow = $blk->fetch(PDO::FETCH_ASSOC);
        if ((int)$blkRow['cnt'] > 0) {
            return false;
        }
        return !$this->recurringBlockOverlaps((int)$court_id, $start_time, $end_time, $sub_court_id);
    }

    /**
     * Annual blocks: same calendar month/day every year, time taken from template row.
     */
    private function recurringBlockOverlaps(int $court_id, string $start_time, string $end_time, $sub_court_id): bool
    {
        if ($sub_court_id !== null) {
            $stmt = $this->conn->prepare(
                "SELECT start_time AS tpl_s, end_time AS tpl_e FROM blocked_slots
                 WHERE court_id = ? AND COALESCE(repeat_annually, 0) = 1
                   AND (sub_court_id IS NULL OR sub_court_id = ?)"
            );
            $stmt->execute([$court_id, $sub_court_id]);
        } else {
            $stmt = $this->conn->prepare(
                "SELECT start_time AS tpl_s, end_time AS tpl_e FROM blocked_slots
                 WHERE court_id = ? AND COALESCE(repeat_annually, 0) = 1 AND sub_court_id IS NULL"
            );
            $stmt->execute([$court_id]);
        }

        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            if (ScheduleRules::annualTemplateHits($start_time, $end_time, $row['tpl_s'], $row['tpl_e'])) {
                return true;
            }
        }
        return false;
    }
}
