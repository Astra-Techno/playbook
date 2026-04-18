<?php

class BlockController
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
            CREATE TABLE IF NOT EXISTS blocked_slots (
                id          INT AUTO_INCREMENT PRIMARY KEY,
                court_id    INT NOT NULL,
                start_time  DATETIME NOT NULL,
                end_time    DATETIME NOT NULL,
                reason      VARCHAR(255) DEFAULT NULL,
                blocked_by  INT NOT NULL,
                created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_court_date (court_id, start_time)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        try { $this->db->exec("ALTER TABLE blocked_slots ADD COLUMN sub_court_id INT DEFAULT NULL"); } catch (Exception $e) {}
    }

    // GET /blocked-slots?court_id=X[&sub_court_id=Y][&date=YYYY-MM-DD]
    public function index(): void
    {
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        $date         = $_GET['date'] ?? '';
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        $spaceFilter = $sub_court_id !== null ? ' AND sub_court_id = ?' : ' AND sub_court_id IS NULL';
        $params      = $sub_court_id !== null ? [$court_id, $sub_court_id] : [$court_id];

        if ($date) {
            $stmt = $this->db->prepare("
                SELECT * FROM blocked_slots
                WHERE court_id = ?{$spaceFilter} AND DATE(start_time) = ?
                ORDER BY start_time
            ");
            $stmt->execute(array_merge($params, [$date]));
        } else {
            $stmt = $this->db->prepare("
                SELECT * FROM blocked_slots
                WHERE court_id = ?{$spaceFilter} AND end_time >= NOW()
                ORDER BY start_time LIMIT 200
            ");
            $stmt->execute($params);
        }
        echo json_encode(['blocks' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // POST /blocked-slots  { court_id, sub_court_id?, date, hours: [6,7,8], reason? }
    // OR  { court_id, sub_court_id?, start_time, end_time, reason? }  for range block
    public function create(): void
    {
        $authUser     = Auth::require();
        $blocked_by   = (int)$authUser['id'];
        $data         = json_decode(file_get_contents('php://input'));
        $court_id     = (int)($data->court_id  ?? 0);
        $sub_court_id = isset($data->sub_court_id) && $data->sub_court_id !== '' ? (int)$data->sub_court_id : null;
        $reason       = trim($data->reason ?? '');

        if (!$court_id) {
            http_response_code(400); echo json_encode(['message' => 'court_id required']); return;
        }

        // Verify requester is owner or staff manager
        $ok = $this->db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $ok->execute([$court_id, $blocked_by]);
        if (!$ok->fetch()) {
            $ok2 = $this->db->prepare("SELECT id FROM court_staff WHERE court_id=? AND user_id=? AND role='manager'");
            $ok2->execute([$court_id, $blocked_by]);
            if (!$ok2->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }
        }

        $created = [];

        // Block individual hours on a date
        if (!empty($data->date) && !empty($data->hours) && is_array($data->hours)) {
            $ins = $this->db->prepare("
                INSERT IGNORE INTO blocked_slots (court_id, sub_court_id, start_time, end_time, reason, blocked_by)
                VALUES (?, ?, ?, ?, ?, ?)
            ");
            foreach ($data->hours as $hour) {
                $h   = (int)$hour;
                $st  = $data->date . ' ' . str_pad($h,     2, '0', STR_PAD_LEFT) . ':00:00';
                $et  = $data->date . ' ' . str_pad($h + 1, 2, '0', STR_PAD_LEFT) . ':00:00';
                $ins->execute([$court_id, $sub_court_id, $st, $et, $reason, $blocked_by]);
                $created[] = ['start_time' => $st, 'end_time' => $et];
            }
        } elseif (!empty($data->start_time) && !empty($data->end_time)) {
            // Block a continuous range
            $ins = $this->db->prepare("
                INSERT INTO blocked_slots (court_id, sub_court_id, start_time, end_time, reason, blocked_by)
                VALUES (?, ?, ?, ?, ?, ?)
            ");
            $ins->execute([$court_id, $sub_court_id, $data->start_time, $data->end_time, $reason, $blocked_by]);
            $created[] = ['start_time' => $data->start_time, 'end_time' => $data->end_time];
        } else {
            http_response_code(400); echo json_encode(['message' => 'Provide date+hours or start_time+end_time']); return;
        }

        http_response_code(201);
        echo json_encode(['message' => 'Slots blocked', 'created' => count($created)]);
    }

    // DELETE /blocked-slots/:id
    public function delete(int $id): void
    {
        $authUser   = Auth::require();
        $blocked_by = (int)$authUser['id'];

        $chk = $this->db->prepare("
            SELECT bs.id FROM blocked_slots bs
            JOIN courts c ON c.id = bs.court_id
            WHERE bs.id = ? AND (c.owner_id = ? OR bs.blocked_by = ?)
        ");
        $chk->execute([$id, $blocked_by, $blocked_by]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }

        $this->db->prepare("DELETE FROM blocked_slots WHERE id = ?")->execute([$id]);
        echo json_encode(['message' => 'Block removed']);
    }
}
