<?php

require_once __DIR__ . '/../../config/database.php';

class WaitlistController {

    private function ensureTable($db) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS waitlist (
                id              INT AUTO_INCREMENT PRIMARY KEY,
                user_id         INT NOT NULL,
                court_id        INT NOT NULL,
                sub_court_id    INT NULL,
                booking_date    DATE NOT NULL,
                start_time      TIME NOT NULL,
                end_time        TIME NOT NULL,
                status          ENUM('waiting','notified','expired') NOT NULL DEFAULT 'waiting',
                created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_slot (court_id, sub_court_id, booking_date, start_time),
                FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
                FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }

    // POST /waitlist  { court_id, sub_court_id?, booking_date, start_time, end_time }
    public function create() {
        $authUser     = Auth::require();
        $user_id      = (int)$authUser['id'];
        $data         = json_decode(file_get_contents('php://input'));
        $court_id     = (int)($data->court_id ?? 0);
        $sub_court_id = isset($data->sub_court_id) ? (int)$data->sub_court_id : null;
        $date         = $data->booking_date ?? '';
        $start        = $data->start_time   ?? '';
        $end          = $data->end_time     ?? '';

        if (!$court_id || !$date || !$start || !$end) {
            http_response_code(400); echo json_encode(['message' => 'Missing fields']); return;
        }

        $db = Database::getConnection();
        $this->ensureTable($db);

        // Prevent duplicate entries
        $chk = $db->prepare("SELECT id FROM waitlist WHERE user_id=? AND court_id=? AND booking_date=? AND start_time=? AND status='waiting'");
        $chk->execute([$user_id, $court_id, $date, $start]);
        if ($chk->fetch()) {
            http_response_code(409); echo json_encode(['message' => 'Already on waitlist for this slot']); return;
        }

        $stmt = $db->prepare("INSERT INTO waitlist (user_id, court_id, sub_court_id, booking_date, start_time, end_time) VALUES (?,?,?,?,?,?)");
        $stmt->execute([$user_id, $court_id, $sub_court_id, $date, $start, $end]);

        http_response_code(201);
        echo json_encode(['message' => 'Added to waitlist', 'id' => (int)$db->lastInsertId()]);
    }

    // GET /waitlist
    public function index() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $db = Database::getConnection();
        $this->ensureTable($db);

        $stmt = $db->prepare("
            SELECT w.id, w.status, w.created_at,
                   w.booking_date, w.start_time, w.end_time,
                   c.name AS court_name,
                   COALESCE(sc.name,'') AS space_name
            FROM waitlist w
            JOIN courts c ON c.id = w.court_id
            LEFT JOIN sub_courts sc ON sc.id = w.sub_court_id
            WHERE w.user_id = ? AND w.booking_date >= CURDATE()
            ORDER BY w.booking_date ASC, w.start_time ASC
        ");
        $stmt->execute([$user_id]);
        echo json_encode(['entries' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // DELETE /waitlist/:id
    public function delete($id) {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $db = Database::getConnection();
        $this->ensureTable($db);

        $stmt = $db->prepare("DELETE FROM waitlist WHERE id=? AND user_id=?");
        $stmt->execute([$id, $user_id]);
        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Removed from waitlist']);
        } else {
            http_response_code(404); echo json_encode(['message' => 'Not found']);
        }
    }

    // Called internally when a booking is cancelled — notifies first waitlisted user
    public static function notifyNext($db, int $court_id, ?int $sub_court_id, string $date, string $start, string $end) {
        $stmt = $db->prepare("
            SELECT w.id, w.user_id, c.name AS court_name
            FROM waitlist w
            JOIN courts c ON c.id = w.court_id
            WHERE w.court_id=? AND (w.sub_court_id=? OR ? IS NULL)
              AND w.booking_date=? AND w.start_time<=? AND w.end_time>=?
              AND w.status='waiting'
            ORDER BY w.created_at ASC LIMIT 1
        ");
        $stmt->execute([$court_id, $sub_court_id, $sub_court_id, $date, $start, $end]);
        $entry = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$entry) return;

        // Mark as notified
        $db->prepare("UPDATE waitlist SET status='notified' WHERE id=?")->execute([$entry['id']]);

        // Create in-app notification
        $notifStmt = $db->prepare("
            INSERT INTO user_notifications (user_id, type, title, body, data_json)
            VALUES (?, 'waitlist_slot_open', 'Slot Available!',
                    CONCAT('A slot opened at ', ?),
                    JSON_OBJECT('court_id', ?, 'date', ?, 'start', ?))
        ");
        $notifStmt->execute([$entry['user_id'], $entry['court_name'], $court_id, $date, $start]);
    }
}
