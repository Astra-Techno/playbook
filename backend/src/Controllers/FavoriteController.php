<?php
require_once __DIR__ . '/../../config/database.php';

class FavoriteController {

    // GET /favorites?user_id=X
    public function index() {
        $user_id = (int)($_GET['user_id'] ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }
        $db   = Database::getConnection();
        $stmt = $db->prepare("SELECT f.court_id FROM favorites f WHERE f.user_id = ?");
        $stmt->execute([$user_id]);
        $ids = array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'court_id');
        http_response_code(200);
        echo json_encode(['ids' => $ids]);
    }

    // POST /favorites  { user_id, court_id }
    public function toggle() {
        $data     = json_decode(file_get_contents('php://input'));
        $user_id  = (int)($data->user_id  ?? 0);
        $court_id = (int)($data->court_id ?? 0);
        if (!$user_id || !$court_id) { http_response_code(400); echo json_encode(['message' => 'user_id and court_id required']); return; }
        $db   = Database::getConnection();
        $check = $db->prepare("SELECT id FROM favorites WHERE user_id=? AND court_id=?");
        $check->execute([$user_id, $court_id]);
        if ($check->fetch()) {
            $db->prepare("DELETE FROM favorites WHERE user_id=? AND court_id=?")->execute([$user_id, $court_id]);
            http_response_code(200);
            echo json_encode(['favorited' => false]);
        } else {
            $db->prepare("INSERT INTO favorites (user_id, court_id) VALUES (?,?)")->execute([$user_id, $court_id]);
            http_response_code(200);
            echo json_encode(['favorited' => true]);
        }
    }
}
