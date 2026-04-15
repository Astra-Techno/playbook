<?php

require_once __DIR__ . '/../../config/database.php';

class ReviewController {

    // GET /api/reviews?court_id=X  or  ?owner_id=X
    public function index() {
        $court_id = (int)($_GET['court_id'] ?? 0);
        $owner_id = (int)($_GET['owner_id'] ?? 0);

        $db = Database::getConnection();

        // All reviews across owner's courts
        if ($owner_id && !$court_id) {
            $stmt = $db->prepare(
                "SELECT r.id, r.court_id, r.rating, r.comment, r.created_at,
                        r.owner_reply, r.owner_reply_at,
                        u.name as user_name, c.name as court_name
                 FROM reviews r
                 JOIN users u  ON r.user_id  = u.id
                 JOIN courts c ON r.court_id = c.id
                 WHERE c.owner_id = ?
                 ORDER BY r.created_at DESC LIMIT 50"
            );
            $stmt->execute([$owner_id]);
            echo json_encode(["records" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            return;
        }

        if (!$court_id) {
            http_response_code(400);
            echo json_encode(["message" => "court_id required"]);
            return;
        }

        $stmt = $db->prepare(
            "SELECT r.id, r.rating, r.comment, r.created_at,
                    r.owner_reply, r.owner_reply_at, u.name as user_name
             FROM reviews r
             JOIN users u ON r.user_id = u.id
             WHERE r.court_id = ?
             ORDER BY r.created_at DESC
             LIMIT 20"
        );
        $stmt->execute([$court_id]);
        $records = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $avgStmt = $db->prepare("SELECT AVG(rating) as avg, COUNT(*) as cnt FROM reviews WHERE court_id = ?");
        $avgStmt->execute([$court_id]);
        $stats = $avgStmt->fetch(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode([
            "records"    => $records,
            "avg_rating" => $stats['cnt'] > 0 ? round((float)$stats['avg'], 1) : null,
            "count"      => (int)$stats['cnt'],
        ]);
    }

    // POST /api/reviews  { court_id, user_id, booking_id, rating, comment }
    public function create() {
        $data       = json_decode(file_get_contents("php://input"));
        $court_id   = (int)($data->court_id   ?? 0);
        $user_id    = (int)($data->user_id    ?? 0);
        $booking_id = (int)($data->booking_id ?? 0);
        $rating     = (int)($data->rating     ?? 0);
        $comment    = htmlspecialchars(strip_tags(trim($data->comment ?? '')));

        if (!$court_id || !$user_id || !$booking_id || $rating < 1 || $rating > 5) {
            http_response_code(400);
            echo json_encode(["message" => "Invalid review data"]);
            return;
        }

        $db = Database::getConnection();

        // Verify user owns this past booking for this court
        $check = $db->prepare(
            "SELECT id FROM bookings WHERE id=? AND user_id=? AND court_id=? AND start_time <= NOW()"
        );
        $check->execute([$booking_id, $user_id, $court_id]);
        if (!$check->fetch()) {
            http_response_code(403);
            echo json_encode(["message" => "You must have completed this booking to review it"]);
            return;
        }

        try {
            $stmt = $db->prepare(
                "INSERT INTO reviews (court_id, user_id, booking_id, rating, comment) VALUES (?,?,?,?,?)"
            );
            $stmt->execute([$court_id, $user_id, $booking_id, $rating, $comment]);
            http_response_code(201);
            echo json_encode(["message" => "Review submitted!"]);
        } catch (\PDOException $e) {
            http_response_code(409);
            echo json_encode(["message" => "Already reviewed this booking"]);
        }
    }

    // PUT /api/reviews/:id/reply  { owner_id, reply }
    public function reply($id) {
        $data     = json_decode(file_get_contents("php://input"));
        $owner_id = (int)($data->owner_id ?? 0);
        $reply    = htmlspecialchars(strip_tags(trim($data->reply ?? '')));
        if (!$id || !$owner_id || !$reply) {
            http_response_code(400); echo json_encode(['message' => 'owner_id and reply required']); return;
        }
        $db  = Database::getConnection();
        $chk = $db->prepare(
            "SELECT r.id FROM reviews r JOIN courts c ON c.id = r.court_id WHERE r.id=? AND c.owner_id=?"
        );
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Not authorised']); return; }
        $db->prepare("UPDATE reviews SET owner_reply=?, owner_reply_at=NOW() WHERE id=?")->execute([$reply, $id]);
        http_response_code(200);
        echo json_encode(['message' => 'Reply saved.']);
    }
}
