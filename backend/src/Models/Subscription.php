<?php
require_once __DIR__ . '/../../config/database.php';

class Subscription {
    private $conn;
    private $table = "user_subscriptions";

    public function __construct() {
        $this->conn = Database::getConnection();
    }

    /**
     * Check if user has an active subscription for a court
     * that covers the given slot_type (morning/evening/full_day/unlimited).
     * Returns the subscription row or false.
     */
    public function getActive($user_id, $court_id) {
        $today = date('Y-m-d');
        $stmt  = $this->conn->prepare(
            "SELECT * FROM {$this->table}
             WHERE user_id=? AND court_id=? AND status='active' AND end_date >= ?
             ORDER BY end_date DESC LIMIT 1"
        );
        $stmt->execute([$user_id, $court_id, $today]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: false;
    }

    /** Returns true when the subscription slot_type covers the requested peak type */
    public static function coversSlot($sub_slot_type, $requested) {
        if ($sub_slot_type === 'unlimited' || $sub_slot_type === 'full_day') return true;
        return $sub_slot_type === $requested;
    }

    public function create($user_id, $plan_id, $court_id, $slot_type, $duration_days) {
        $start = date('Y-m-d');
        $end   = date('Y-m-d', strtotime("+{$duration_days} days"));
        $stmt  = $this->conn->prepare(
            "INSERT INTO {$this->table}
             SET user_id=:uid, plan_id=:pid, court_id=:cid,
                 slot_type=:st, start_date=:sd, end_date=:ed, status='active'"
        );
        $stmt->bindParam(':uid', $user_id);
        $stmt->bindParam(':pid', $plan_id);
        $stmt->bindParam(':cid', $court_id);
        $stmt->bindParam(':st',  $slot_type);
        $stmt->bindParam(':sd',  $start);
        $stmt->bindParam(':ed',  $end);
        return $stmt->execute();
    }

    public function listByUser($user_id) {
        $stmt = $this->conn->prepare(
            "SELECT us.*, p.name as plan_name, p.slot_type, c.name as court_name
             FROM {$this->table} us
             JOIN plans p  ON us.plan_id  = p.id
             JOIN courts c ON us.court_id = c.id
             WHERE us.user_id=? ORDER BY us.created_at DESC"
        );
        $stmt->execute([$user_id]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
