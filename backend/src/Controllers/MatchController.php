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

    // GET /match-requests?court_id=X  or no params = all open (global discovery)
    public function index(): void
    {
        $court_id = (int)($_GET['court_id'] ?? 0);
        $authUser = Auth::user();
        $user_id  = (!$court_id && $authUser) ? (int)$authUser['id'] : 0;

        if ($court_id) {
            $stmt = $this->db->prepare("
                SELECT mr.*, mr.user_id AS created_by, mr.players_needed AS slots_needed,
                       CONCAT(mr.date, ' ', mr.start_time) AS play_time,
                       u.name AS creator_name, u.avatar_url AS creator_avatar,
                       c.name AS court_name, c.location AS court_location,
                       (SELECT COUNT(*) FROM match_participants mp WHERE mp.match_id = mr.id) AS joined_count
                FROM match_requests mr
                JOIN users u ON u.id = mr.user_id
                JOIN courts c ON c.id = mr.court_id
                WHERE mr.court_id = ? AND mr.status != 'cancelled' AND mr.date >= CURDATE()
                ORDER BY mr.date, mr.start_time
            ");
            $stmt->execute([$court_id]);
        } elseif ($user_id) {
            $stmt = $this->db->prepare("
                SELECT mr.*, mr.user_id AS created_by, mr.players_needed AS slots_needed,
                       CONCAT(mr.date, ' ', mr.start_time) AS play_time,
                       u.name AS creator_name, u.avatar_url AS creator_avatar,
                       c.name AS court_name, c.location AS court_location,
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
            // Global discovery — all open requests (public)
            $stmt = $this->db->prepare("
                SELECT mr.*, mr.user_id AS created_by, mr.players_needed AS slots_needed,
                       CONCAT(mr.date, ' ', mr.start_time) AS play_time,
                       u.name AS creator_name, u.avatar_url AS creator_avatar,
                       c.name AS court_name, c.location AS court_location,
                       (SELECT COUNT(*) FROM match_participants mp WHERE mp.match_id = mr.id) AS joined_count
                FROM match_requests mr
                JOIN users u ON u.id = mr.user_id
                JOIN courts c ON c.id = mr.court_id
                WHERE mr.status != 'cancelled' AND mr.date >= CURDATE()
                ORDER BY mr.date, mr.start_time
                LIMIT 100
            ");
            $stmt->execute();
        }

        $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Attach participants list + add user_id to each participant for isMember checks
        foreach ($requests as &$r) {
            $pStmt = $this->db->prepare("
                SELECT u.id AS user_id, u.name, u.avatar_url FROM match_participants mp
                JOIN users u ON u.id = mp.user_id WHERE mp.match_id = ?
            ");
            $pStmt->execute([$r['id']]);
            $r['participants'] = $pStmt->fetchAll(PDO::FETCH_ASSOC);
            // Derive status from participant count vs slots_needed
            if ($r['status'] === 'open' && count($r['participants']) >= (int)$r['slots_needed']) {
                $r['status'] = 'full';
            }
        }

        echo json_encode(['requests' => $requests]);
    }

    // POST /match-requests
    // Accepts both formats:
    //   { court_id, sport, play_time:"YYYY-MM-DD HH:MM:SS", slots_needed, notes }  (MatchSheet)
    //   { court_id, title, sport, date, start_time, end_time, players_needed, notes }  (legacy)
    public function create(): void
    {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $data = json_decode(file_get_contents('php://input'));

        if (empty($data->court_id)) {
            http_response_code(400); echo json_encode(['message' => 'court_id required']); return;
        }

        // Resolve date + start_time + end_time from either format
        if (!empty($data->play_time)) {
            $ts         = strtotime($data->play_time);
            $date       = date('Y-m-d', $ts);
            $start_time = date('H:i:s', $ts);
            $end_time   = date('H:i:s', $ts + 3600); // default 1h duration
        } else {
            $date       = $data->date       ?? '';
            $start_time = $data->start_time ?? '';
            $end_time   = $data->end_time   ?? date('H:i:s', strtotime($data->start_time ?? '00:00:00') + 3600);
        }

        // Resolve players_needed from either field name
        $slots_needed = (int)($data->slots_needed ?? $data->players_needed ?? 2);
        $title        = trim($data->title ?? '') ?: 'Looking for players';
        $sport        = trim($data->sport ?? '') ?: null;

        if (!$date || !$start_time) {
            http_response_code(400); echo json_encode(['message' => 'date/play_time required']); return;
        }

        $ins = $this->db->prepare("
            INSERT INTO match_requests (court_id, user_id, title, sport, date, start_time, end_time, players_needed, notes)
            VALUES (?,?,?,?,?,?,?,?,?)
        ");
        $ins->execute([
            (int)$data->court_id, $user_id,
            $title, $sport, $date, $start_time, $end_time,
            $slots_needed,
            trim($data->notes ?? '') ?: null,
        ]);
        $newId = (int)$this->db->lastInsertId();

        // Creator auto-joins
        try {
            $this->db->prepare("INSERT INTO match_participants (match_id, user_id) VALUES (?,?)")
                     ->execute([$newId, $user_id]);
        } catch (Exception $e) {}

        http_response_code(201);
        echo json_encode(['message' => 'Match request created', 'id' => $newId]);
    }

    // POST /match-requests/:id/join
    public function join(int $id): void
    {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

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

    // DELETE /match-requests/:id
    public function cancel(int $id): void
    {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $chk      = $this->db->prepare("SELECT id FROM match_requests WHERE id=? AND user_id=?");
        $chk->execute([$id, $user_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }
        $this->db->prepare("UPDATE match_requests SET status='cancelled' WHERE id=?")->execute([$id]);
        echo json_encode(['message' => 'Cancelled']);
    }

    // DELETE /match-requests/:id/leave
    public function leave(int $id): void
    {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $this->db->prepare("DELETE FROM match_participants WHERE match_id=? AND user_id=?")->execute([$id, $user_id]);
        // Re-open if was full
        $this->db->prepare("UPDATE match_requests SET status='open' WHERE id=? AND status='full'")->execute([$id]);
        echo json_encode(['message' => 'Left match']);
    }
}
