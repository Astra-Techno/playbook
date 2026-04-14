<?php

require_once __DIR__ . '/../../config/database.php';

class Booking {
    public $conn;
    private $table_name = "bookings";

    public $id;
    public $user_id;
    public $court_id;
    public $start_time;
    public $end_time;
    public $type;
    public $total_price;
    public $status;
    public $payment_status;

    public function __construct() {
        $this->conn = Database::getConnection();
    }

    // Create booking
    public function create() {
        $query = "INSERT INTO " . $this->table_name . " 
                  SET user_id=:user_id, court_id=:court_id, start_time=:start_time, 
                      end_time=:end_time, type=:type, total_price=:total_price, 
                      status='confirmed', payment_status='paid'"; // Simplified for MVP

        $stmt = $this->conn->prepare($query);

        $this->start_time = htmlspecialchars(strip_tags($this->start_time));
        $this->end_time = htmlspecialchars(strip_tags($this->end_time));
        $this->type = htmlspecialchars(strip_tags($this->type));
        $this->total_price = htmlspecialchars(strip_tags($this->total_price));

        $stmt->bindParam(":user_id", $this->user_id);
        $stmt->bindParam(":court_id", $this->court_id);
        $stmt->bindParam(":start_time", $this->start_time);
        $stmt->bindParam(":end_time", $this->end_time);
        $stmt->bindParam(":type", $this->type);
        $stmt->bindParam(":total_price", $this->total_price);

        if ($stmt->execute()) {
            return true;
        }
        return false;
    }

    public function readByUser($user_id) {
        $query = "SELECT b.*, c.name as court_name" .
                 " FROM " . $this->table_name . " b" .
                 " JOIN courts c ON b.court_id = c.id" .
                 " WHERE b.user_id = ? AND b.status != 'cancelled'" .
                 " ORDER BY b.start_time DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $user_id);
        $stmt->execute();
        return $stmt;
    }
    /**
     * Return bookings for a specific court on a specific date.
     */
    public function readByCourtAndDate($court_id, $date) {
        $query = "SELECT * FROM " . $this->table_name .
                 " WHERE court_id = :court_id" .
                 " AND DATE(start_time) = :date" .
                 " AND status = 'confirmed'" .
                 " ORDER BY start_time";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':court_id', $court_id);
        $stmt->bindParam(':date', $date);
        $stmt->execute();
        return $stmt;
    }

    /**
     * Check if the desired time slot is available (no overlapping confirmed booking).
     * Returns true when available.
     */
    public function isSlotAvailable($court_id, $start_time, $end_time) {
        $query = "SELECT COUNT(*) as cnt FROM " . $this->table_name .
                 " WHERE court_id = :court_id" .
                 " AND (start_time < :end_time AND end_time > :start_time)" .
                 " AND status = 'confirmed'";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':court_id', $court_id);
        $stmt->bindParam(':start_time', $start_time);
        $stmt->bindParam(':end_time', $end_time);
        $stmt->execute();
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row['cnt'] == 0;
    }
}
