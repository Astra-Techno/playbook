<?php

require_once __DIR__ . '/../../config/database.php';

class CourtPhotoController {

    // GET /api/court-photos?court_id=X
    public function index() {
        $court_id = (int)($_GET['court_id'] ?? 0);
        if (!$court_id) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id required']);
            return;
        }
        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT id, url, sort_order FROM court_photos WHERE court_id = ? ORDER BY sort_order ASC, id ASC"
        );
        $stmt->execute([$court_id]);
        http_response_code(200);
        echo json_encode(['photos' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // POST /api/court-photos  { court_id, owner_id, url, sort_order? }
    public function create() {
        $data     = json_decode(file_get_contents('php://input'));
        $court_id = (int)($data->court_id ?? 0);
        $owner_id = (int)($data->owner_id ?? 0);
        $url      = trim($data->url ?? '');
        $sort     = (int)($data->sort_order ?? 0);

        if (!$court_id || !$owner_id || !$url) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id, owner_id, url required']);
            return;
        }

        $db  = Database::getConnection();
        // Verify ownership
        $chk = $db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$court_id, $owner_id]);
        if (!$chk->fetch()) {
            http_response_code(403);
            echo json_encode(['message' => 'Not authorised']);
            return;
        }

        $stmt = $db->prepare(
            "INSERT INTO court_photos (court_id, url, sort_order) VALUES (?,?,?)"
        );
        $stmt->execute([$court_id, $url, $sort]);
        $newId = (int)$db->lastInsertId();
        http_response_code(201);
        echo json_encode(['message' => 'Photo added.', 'id' => $newId]);
    }

    // DELETE /api/court-photos/:id  body: { owner_id }
    public function delete($id) {
        $data     = json_decode(file_get_contents('php://input'));
        $owner_id = (int)($data->owner_id ?? 0);
        if (!$id || !$owner_id) {
            http_response_code(400);
            echo json_encode(['message' => 'id and owner_id required']);
            return;
        }
        $db  = Database::getConnection();
        // Verify ownership via join
        $chk = $db->prepare(
            "SELECT cp.id FROM court_photos cp JOIN courts c ON c.id = cp.court_id WHERE cp.id=? AND c.owner_id=?"
        );
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) {
            http_response_code(403);
            echo json_encode(['message' => 'Not authorised']);
            return;
        }
        $db->prepare("DELETE FROM court_photos WHERE id=?")->execute([$id]);
        http_response_code(200);
        echo json_encode(['message' => 'Photo deleted.']);
    }
}
