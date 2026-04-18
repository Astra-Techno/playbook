<?php

class PricingController
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getConnection();
        $this->ensureTable();
    }

    private function ensureTable(): void
    {
        $this->db->exec("
            CREATE TABLE IF NOT EXISTS pricing_rules (
                id            INT AUTO_INCREMENT PRIMARY KEY,
                court_id      INT NOT NULL,
                sub_court_id  INT DEFAULT NULL,
                name          VARCHAR(100) NOT NULL,
                day_type      ENUM('all','weekday','weekend') DEFAULT 'all',
                start_hour    TINYINT DEFAULT 0,
                end_hour      TINYINT DEFAULT 23,
                price         DECIMAL(10,2) NOT NULL,
                valid_from    DATE DEFAULT NULL,
                valid_to      DATE DEFAULT NULL,
                priority      INT DEFAULT 0,
                created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_court (court_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        try { $this->db->exec("ALTER TABLE pricing_rules ADD COLUMN sub_court_id INT DEFAULT NULL"); } catch (Exception $e) {}
    }

    // GET /pricing-rules?court_id=X[&sub_court_id=Y]
    public function index(): void
    {
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        if ($sub_court_id) {
            $stmt = $this->db->prepare("SELECT * FROM pricing_rules WHERE court_id=? AND sub_court_id=? ORDER BY priority DESC, id");
            $stmt->execute([$court_id, $sub_court_id]);
        } else {
            $stmt = $this->db->prepare("SELECT * FROM pricing_rules WHERE court_id=? AND sub_court_id IS NULL ORDER BY priority DESC, id");
            $stmt->execute([$court_id]);
        }
        echo json_encode(['rules' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // POST /pricing-rules  { court_id, sub_court_id?, name, day_type, start_hour, end_hour, price, valid_from?, valid_to? }
    public function create(): void
    {
        $authUser     = Auth::requireOwner();
        $owner_id     = (int)$authUser['id'];
        $data         = json_decode(file_get_contents('php://input'));
        $court_id     = (int)($data->court_id ?? 0);
        $sub_court_id = isset($data->sub_court_id) && $data->sub_court_id !== '' ? (int)$data->sub_court_id : null;
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }
        $chk = $this->db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$court_id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }

        $ins = $this->db->prepare("
            INSERT INTO pricing_rules (court_id, sub_court_id, name, day_type, start_hour, end_hour, price, valid_from, valid_to, priority)
            VALUES (?,?,?,?,?,?,?,?,?,?)
        ");
        $ins->execute([
            $court_id,
            $sub_court_id,
            trim($data->name ?? 'Custom Rate'),
            in_array($data->day_type ?? '', ['all','weekday','weekend']) ? $data->day_type : 'all',
            (int)($data->start_hour ?? 0),
            (int)($data->end_hour   ?? 23),
            (float)($data->price    ?? 0),
            !empty($data->valid_from) ? $data->valid_from : null,
            !empty($data->valid_to)   ? $data->valid_to   : null,
            (int)($data->priority   ?? 0),
        ]);
        $newId = (int)$this->db->lastInsertId();
        $row   = $this->db->prepare("SELECT * FROM pricing_rules WHERE id=?");
        $row->execute([$newId]);
        http_response_code(201);
        echo json_encode(['message' => 'Rule created', 'rule' => $row->fetch(PDO::FETCH_ASSOC)]);
    }

    // DELETE /pricing-rules/:id
    public function delete(int $id): void
    {
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];
        $data     = json_decode(file_get_contents('php://input'));
        $chk = $this->db->prepare("SELECT pr.id FROM pricing_rules pr JOIN courts c ON c.id=pr.court_id WHERE pr.id=? AND c.owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }
        $this->db->prepare("DELETE FROM pricing_rules WHERE id=?")->execute([$id]);
        echo json_encode(['message' => 'Deleted']);
    }

    // GET /pricing-rules/calculate?court_id=X&date=YYYY-MM-DD&hour=H[&sub_court_id=Y]
    // Returns the effective price for a given slot
    public function calculate(): void
    {
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        $date         = $_GET['date'] ?? date('Y-m-d');
        $hour         = (int)($_GET['hour'] ?? 0);
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        echo json_encode($this->getSlotPrice($court_id, $sub_court_id, $date, $hour));
    }

    // GET /pricing-rules/calculate-day?court_id=X&date=YYYY-MM-DD[&sub_court_id=Y]
    // Returns effective_price for every hour 0-23 in one call
    public function calculateDay(): void
    {
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        $date         = $_GET['date'] ?? date('Y-m-d');
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        $prices = [];
        for ($h = 0; $h <= 23; $h++) {
            $prices[$h] = $this->getSlotPrice($court_id, $sub_court_id, $date, $h)['effective_price'];
        }
        http_response_code(200);
        echo json_encode(['prices' => $prices, 'date' => $date]);
    }

    // Internal: resolve effective price for one hour
    private function getSlotPrice(int $court_id, ?int $sub_court_id, string $date, int $hour): array
    {
        $dow       = (int)date('N', strtotime($date));
        $isWeekend = $dow >= 6;
        $dayType   = $isWeekend ? 'weekend' : 'weekday';

        // Base rate from court
        $cStmt = $this->db->prepare("SELECT hourly_rate FROM courts WHERE id=?");
        $cStmt->execute([$court_id]);
        $court     = $cStmt->fetch(PDO::FETCH_ASSOC);
        $basePrice = (float)($court['hourly_rate'] ?? 0);

        // Override base with space hourly_rate if space exists
        if ($sub_court_id) {
            $scStmt = $this->db->prepare("SELECT hourly_rate FROM sub_courts WHERE id=?");
            $scStmt->execute([$sub_court_id]);
            $sc = $scStmt->fetch(PDO::FETCH_ASSOC);
            if ($sc && $sc['hourly_rate'] !== null && $sc['hourly_rate'] > 0) {
                $basePrice = (float)$sc['hourly_rate'];
            }
        }

        $rule = null;

        // 1. Try space-specific rule first
        if ($sub_court_id) {
            $stmt = $this->db->prepare("
                SELECT * FROM pricing_rules
                WHERE court_id = ? AND sub_court_id = ?
                  AND start_hour <= ? AND end_hour > ?
                  AND (day_type = 'all' OR day_type = ?)
                  AND (valid_from IS NULL OR valid_from <= ?)
                  AND (valid_to   IS NULL OR valid_to   >= ?)
                ORDER BY priority DESC, id DESC LIMIT 1
            ");
            $stmt->execute([$court_id, $sub_court_id, $hour, $hour, $dayType, $date, $date]);
            $rule = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
        }

        // 2. Fall back to venue-level rule
        if (!$rule) {
            $stmt = $this->db->prepare("
                SELECT * FROM pricing_rules
                WHERE court_id = ? AND sub_court_id IS NULL
                  AND start_hour <= ? AND end_hour > ?
                  AND (day_type = 'all' OR day_type = ?)
                  AND (valid_from IS NULL OR valid_from <= ?)
                  AND (valid_to   IS NULL OR valid_to   >= ?)
                ORDER BY priority DESC, id DESC LIMIT 1
            ");
            $stmt->execute([$court_id, $hour, $hour, $dayType, $date, $date]);
            $rule = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
        }

        $effectivePrice = $rule ? (float)$rule['price'] : $basePrice;
        return [
            'base_price'      => $basePrice,
            'effective_price' => $effectivePrice,
            'rule'            => $rule,
        ];
    }
}
