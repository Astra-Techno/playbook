<?php

class MatchController
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
            CREATE TABLE IF NOT EXISTS match_requests (
                id             INT AUTO_INCREMENT PRIMARY KEY,
                court_id       INT NOT NULL,
                user_id        INT NOT NULL,
                title          VARCHAR(150) NOT NULL,
                sport          VARCHAR(50)  DEFAULT NULL,
                date           DATE         NOT NULL,
                start_time     TIME         NOT NULL,
                end_time       TIME         NOT NULL,
                players_needed TINYINT      DEFAULT 1,
                notes          TEXT         DEFAULT NULL,
                status         ENUM('open','full','cancelled') DEFAULT 'open',
                created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_court_date (court_id, date),
                INDEX idx_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        $this->db->exec("
            CREATE TABLE IF NOT EXISTS match_participants (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                match_id   INT NOT NULL,
                user_id    INT NOT NULL,
                joined_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_match_user (match_id, user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }

    // GET /match-requests?court_id=X  or  ?user_id=X
    public function index(): void
    {
        $court_id = (int)($_GET['court_id'] ?? 0);
        $user_id  = (int)($_GET['user_id']  ?? 0);

        if ($court_id) {
            $stmt = $this->db->prepare("
                SELECT mr.*,
                       u.name AS creator_name, u.avatar_url AS creator_avatar,
                       (SELECT COUNT(*) FROM match_participants mp WHERE mp.match_id = mr.id) AS joined_count
                FROM match_requests mr
                JOIN users u ON u.id = mr.user_id
                WHERE mr.court_id = ? AND mr.status != 'cancelled' AND mr.date >= CURDATE()
                ORDER BY mr.date, mr.start_time
            ");
            $stmt->execute([$court_id]);
        } elseif ($user_id) {
            $stmt = $this->db->prepare("
                SELECT mr.*,
                       u.name AS creator_name, u.avatar_url AS creator_avatar,
                       c.name AS court_name,
                       (SELECT COUNT(*) FROM match_participants mp WHERE mp.match_id = mr.id) AS joined_count
                FROM match_requests mr
                JOIN users u ON u.id = mr.user_id
                JOIN courts c ON c.id = mr.court_id
                WHERE (mr.user_id = ? OR mr.id IN (SELECT match_id FROM match_participants WHERE user_id = ?))
                  AND mr.status != 'cancelled'
                ORDER BY mr.date DESC, mr.start_time DESC
            ");
            $stmt->execute([$user_id, $user_id]);
        } else {
            http_response_code(400); echo json_encode(['message' => 'court_id or user_id required']); return;
        }

        $matches = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Attach participants list to each match
        foreach ($matches as &$m) {
            $pStmt = $this->db->prepare("
                SELECT u.id, u.name, u.avatar_url FROM match_participants mp
                JOIN users u ON u.id = mp.user_id WHERE mp.match_id = ?
            ");
            $pStmt->execute([$m['id']]);
            $m['participants'] = $pStmt->fetchAll(PDO::FETCH_ASSOC);
        }

        echo json_encode(['matches' => $matches]);
    }

    // POST /match-requests  { court_id, user_id, title, sport?, date, start_time, end_time, players_needed, notes? }
    public function create(): void
    {
        $data = json_decode(file_get_contents('php://input'));
        $required = ['court_id','user_id','title','date','start_time','end_time','players_needed'];
        foreach ($required as $f) {
            if (empty($data->$f)) { http_response_code(400); echo json_encode(['message' => "$f required"]); return; }
        }

        $ins = $this->db->prepare("
            INSERT INTO match_requests (court_id, user_id, title, sport, date, start_time, end_time, players_needed, notes)
            VALUES (?,?,?,?,?,?,?,?,?)
        ");
        $ins->execute([
            (int)$data->court_id, (int)$data->user_id,
            trim($data->title),
            trim($data->sport ?? '') ?: null,
            $data->date, $data->start_time, $data->end_time,
            (int)$data->players_needed,
            trim($data->notes ?? '') ?: null,
        ]);
        $newId = (int)$this->db->lastInsertId();

        // Creator auto-joins
        try {
            $this->db->prepare("INSERT INTO match_participants (match_id, user_id) VALUES (?,?)")
                     ->execute([$newId, (int)$data->user_id]);
        } catch (Exception $e) {}

        http_response_code(201);
        echo json_encode(['message' => 'Match request created', 'id' => $newId]);
    }

    // POST /match-requests/:id/join  { user_id }
    public function join(int $id): void
    {
        $data    = json_decode(file_get_contents('php://input'));
        $user_id = (int)($data->user_id ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }

        $mr = $this->db->prepare("SELECT * FROM match_requests WHERE id=? AND status='open'");
        $mr->execute([$id]);
        $match = $mr->fetch(PDO::FETCH_ASSOC);
        if (!$match) { http_response_code(404); echo json_encode(['message' => 'Match not found or not open']); return; }

        // Check if already full
        $cnt = $this->db->prepare("SELECT COUNT(*) FROM match_participants WHERE match_id=?");
        $cnt->execute([$id]);
        $currentCount = (int)$cnt->fetchColumn();
        if ($currentCount >= (int)$match['players_needed'] + 1) { // +1 for creator
            http_response_code(409); echo json_encode(['message' => 'Match is already full']); return;
        }

        try {
            $this->db->prepare("INSERT INTO match_participants (match_id, user_id) VALUES (?,?)")->execute([$id, $user_id]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') { http_response_code(409); echo json_encode(['message' => 'Already joined']); return; }
        }

        // Mark full if needed
        $newCount = $currentCount + 1;
        if ($newCount >= (int)$match['players_needed'] + 1) {
            $this->db->prepare("UPDATE match_requests SET status='full' WHERE id=?")->execute([$id]);
        }

        echo json_encode(['message' => 'Joined successfully']);
    }

    // DELETE /match-requests/:id  { user_id }
    public function cancel(int $id): void
    {
        $data    = json_decode(file_get_contents('php://input'));
        $user_id = (int)($data->user_id ?? 0);
        $chk     = $this->db->prepare("SELECT id FROM match_requests WHERE id=? AND user_id=?");
        $chk->execute([$id, $user_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }
        $this->db->prepare("UPDATE match_requests SET status='cancelled' WHERE id=?")->execute([$id]);
        echo json_encode(['message' => 'Cancelled']);
    }

    // DELETE /match-requests/:id/leave  { user_id }
    public function leave(int $id): void
    {
        $data    = json_decode(file_get_contents('php://input'));
        $user_id = (int)($data->user_id ?? 0);
        $this->db->prepare("DELETE FROM match_participants WHERE match_id=? AND user_id=?")->execute([$id, $user_id]);
        // Re-open if was full
        $this->db->prepare("UPDATE match_requests SET status='open' WHERE id=? AND status='full'")->execute([$id]);
        echo json_encode(['message' => 'Left match']);
    }
}
