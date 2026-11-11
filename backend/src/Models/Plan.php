<?php

require_once __DIR__ . '/../../config/database.php';

class Plan {
    private $conn;
    private $table_name = "plans";

    public $id;
    public $court_id;
    public $sub_court_id;
    public $name;
    public $description;
    public $slot_type;    // morning | evening | full_day | unlimited
    public $duration_days;
    public $price;
    public $benefits;
    public $is_active = 1;

    public function __construct() {
        $this->conn = Database::getConnection();
        try { $this->conn->exec("ALTER TABLE plans ADD COLUMN sub_court_id INT DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->conn->exec("ALTER TABLE plans ADD COLUMN benefits VARCHAR(500) NULL"); } catch (Exception $e) {}
        try { $this->conn->exec("ALTER TABLE plans ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1"); } catch (Exception $e) {}
    }

    public function readByCourt($court_id, $sub_court_id = null, $activeOnly = true) {
        $active = $activeOnly ? ' AND is_active = 1' : '';
        if ($sub_court_id !== null) {
            $stmt = $this->conn->prepare(
                "SELECT * FROM {$this->table_name} WHERE court_id = ? AND sub_court_id = ?{$active} ORDER BY price ASC"
            );
            $stmt->execute([$court_id, $sub_court_id]);
        } else {
            $stmt = $this->conn->prepare(
                "SELECT * FROM {$this->table_name} WHERE court_id = ?{$active} ORDER BY price ASC"
            );
            $stmt->execute([$court_id]);
        }
        return $stmt;
    }

    public function create() {
        $stmt = $this->conn->prepare(
            "INSERT INTO {$this->table_name}
             SET court_id=:court_id, sub_court_id=:sub_court_id, name=:name, description=:description,
                 slot_type=:slot_type, duration_days=:duration_days, price=:price,
                 benefits=:benefits, is_active=:is_active"
        );
        $this->name        = htmlspecialchars(strip_tags($this->name));
        $this->description = htmlspecialchars(strip_tags($this->description ?? ''));
        $this->benefits = htmlspecialchars(strip_tags($this->benefits ?? ''));
        $this->is_active = (int)$this->is_active === 0 ? 0 : 1;
        $this->slot_type   = in_array($this->slot_type, ['morning','evening','full_day','unlimited'])
                             ? $this->slot_type : 'unlimited';
        $stmt->bindParam(":court_id",      $this->court_id);
        $stmt->bindParam(":sub_court_id",  $this->sub_court_id);
        $stmt->bindParam(":name",          $this->name);
        $stmt->bindParam(":description",   $this->description);
        $stmt->bindParam(":slot_type",     $this->slot_type);
        $stmt->bindParam(":duration_days", $this->duration_days);
        $stmt->bindParam(":price",         $this->price);
        $stmt->bindParam(":benefits",      $this->benefits);
        $stmt->bindParam(":is_active",     $this->is_active);
        return $stmt->execute();
    }

    public function activeSubscriberCount() {
        $stmt = $this->conn->prepare(
            "SELECT COUNT(*) FROM user_subscriptions WHERE plan_id = ? AND status = 'active'"
        );
        $stmt->execute([$this->id]);
        return (int) $stmt->fetchColumn();
    }

    public function delete() {
        $stmt = $this->conn->prepare("DELETE FROM {$this->table_name} WHERE id = ?");
        return $stmt->execute([$this->id]);
    }
}
