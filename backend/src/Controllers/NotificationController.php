<?php

require_once __DIR__ . '/../../config/database.php';

class NotificationController {

    private function ensureTable($db) {
        $db->exec("
            CREATE TABLE IF NOT EXISTS user_notifications (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL, type VARCHAR(50) NOT NULL DEFAULT 'info',
                title VARCHAR(255) NOT NULL, body TEXT, court_id INT DEFAULT NULL,
                data_json TEXT DEFAULT NULL,
                is_read TINYINT(1) NOT NULL DEFAULT 0,
                read_at DATETIME DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        // Migrate: add is_read column if missing
        try { $db->exec("ALTER TABLE user_notifications ADD COLUMN is_read TINYINT(1) NOT NULL DEFAULT 0"); } catch (\PDOException $e) {}
    }

    // GET /notifications/list?user_id=X
    public function list() {
        $user_id = (int)($_GET['user_id'] ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }
        $db = Database::getConnection();
        $this->ensureTable($db);
        $stmt = $db->prepare(
            "SELECT n.*, c.name AS court_name FROM user_notifications n
             LEFT JOIN courts c ON c.id = n.court_id
             WHERE n.user_id = ? ORDER BY n.created_at DESC LIMIT 50"
        );
        $stmt->execute([$user_id]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        // unread count
        $cStmt = $db->prepare("SELECT COUNT(*) FROM user_notifications WHERE user_id = ? AND read_at IS NULL AND is_read = 0");
        $cStmt->execute([$user_id]);
        $unread = (int)$cStmt->fetchColumn();
        echo json_encode(['notifications' => $rows, 'unread_count' => $unread]);
    }

    // PUT /notifications/:id/read
    public function markRead($id) {
        $db = Database::getConnection();
        $this->ensureTable($db);
        $db->prepare("UPDATE user_notifications SET read_at = NOW(), is_read = 1 WHERE id = ?")->execute([$id]);
        echo json_encode(['success' => true]);
    }

    // PUT /notifications/read-all  body: { user_id }
    public function markAllRead() {
        $data    = json_decode(file_get_contents('php://input'));
        $user_id = (int)($data->user_id ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }
        $db = Database::getConnection();
        $this->ensureTable($db);
        $db->prepare("UPDATE user_notifications SET read_at = NOW(), is_read = 1 WHERE user_id = ? AND is_read = 0")->execute([$user_id]);
        echo json_encode(['success' => true]);
    }
}
