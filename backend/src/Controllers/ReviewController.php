<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../Push.php';
require_once __DIR__ . '/../ReviewSubmission.php';

class ReviewController {

    // GET /api/reviews?court_id=X  or  ?owner_id=X
    public function index() {
        $court_id = (int)($_GET['court_id'] ?? 0);
        $owner_id = (int)($_GET['owner_id'] ?? 0);
        $authUser = Auth::user();
        $scope = ReviewSubmission::listScope($court_id, $owner_id, $authUser !== null);

        $db = Database::getConnection();

        // All reviews across owner's courts
        if ($scope === 'owner') {
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

        // My reviews — the signed-in player, not a court id
        if ($scope === 'mine') {
            $stmt = $db->prepare(
                "SELECT r.id, r.court_id, r.rating, r.comment, r.created_at,
                        r.owner_reply AS reply, r.owner_reply_at,
                        u.name as user_name, c.name as court_name
                 FROM reviews r
                 JOIN users u ON r.user_id = u.id
                 JOIN courts c ON r.court_id = c.id
                 WHERE r.user_id = ?
                 ORDER BY r.created_at DESC LIMIT 50"
            );
            $stmt->execute([(int)$authUser['id']]);
            echo json_encode(["records" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            return;
        }

        if ($scope === 'court_required') {
            http_response_code(400);
            echo json_encode(["message" => "court_id required"]);
            return;
        }

        $stmt = $db->prepare(
            "SELECT r.id, r.user_id, r.rating, r.comment, r.created_at,
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

    // POST /api/reviews  { court_id, rating, comment, booking_id? }
    public function create() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $review   = ReviewSubmission::fromBody(json_decode(file_get_contents("php://input")));
        $court_id = $review['court_id'];
        $rating   = $review['rating'];
        $comment  = $review['comment'];
        $booking_id = $review['booking_id'];

        if (!$review['ok']) {
            http_response_code(400);
            echo json_encode(["message" => "Invalid review data"]);
            return;
        }

        $db = Database::getConnection();
        $this->allowVenueReview($db);

        if ($booking_id) {
            $check = $db->prepare(
                "SELECT id FROM bookings WHERE id=? AND user_id=? AND court_id=? AND status='confirmed'"
            );
            $check->execute([$booking_id, $user_id, $court_id]);
            if (!$check->fetch()) {
                $booking_id = null;
            }
        }
        if (!$booking_id) {
            $findBooking = $db->prepare(
                "SELECT id FROM bookings WHERE user_id=? AND court_id=? AND status='confirmed' ORDER BY start_time DESC LIMIT 1"
            );
            $findBooking->execute([$user_id, $court_id]);
            $found = $findBooking->fetch(PDO::FETCH_ASSOC);
            if ($found) $booking_id = (int)$found['id'];
        }

        $existing = $db->prepare("SELECT id FROM reviews WHERE user_id=? AND court_id=? LIMIT 1");
        $existing->execute([$user_id, $court_id]);
        if ($existing->fetch()) {
            http_response_code(409);
            echo json_encode(["message" => "You have already reviewed this venue"]);
            return;
        }

        try {
            $stmt = $db->prepare(
                "INSERT INTO reviews (court_id, user_id, booking_id, rating, comment) VALUES (?,?,?,?,?)"
            );
            $stmt->bindValue(1, $court_id, PDO::PARAM_INT);
            $stmt->bindValue(2, $user_id, PDO::PARAM_INT);
            if ($booking_id) {
                $stmt->bindValue(3, $booking_id, PDO::PARAM_INT);
            } else {
                $stmt->bindValue(3, null, PDO::PARAM_NULL);
            }
            $stmt->bindValue(4, $rating, PDO::PARAM_INT);
            $stmt->bindValue(5, $comment, PDO::PARAM_STR);
            $stmt->execute();

            // In-app notification for venue owner
            $courtStmt = $db->prepare("SELECT name, owner_id FROM courts WHERE id = ?");
            $courtStmt->execute([$court_id]);
            $courtRow = $courtStmt->fetch(PDO::FETCH_ASSOC);
            if ($courtRow && !empty($courtRow['owner_id'])) {
                $reviewerName = $authUser['name'] ?? 'Someone';
                $courtName    = $courtRow['name'] ?? 'your venue';

                Push::sendToUser(
                    (int)$courtRow['owner_id'],
                    'New Review',
                    "{$reviewerName} left a {$rating}-star review on {$courtName}",
                    ['type' => 'review', 'court_id' => (string)$court_id]
                );

                try {
                    $db->prepare(
                        "INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?,?,?,?,?)"
                    )->execute([
                        (int)$courtRow['owner_id'],
                        'review',
                        'New Review',
                        "{$reviewerName} left a {$rating}-star review on {$courtName}",
                        $court_id
                    ]);
                } catch (\PDOException $e) {}
            }

            http_response_code(201);
            echo json_encode(["message" => "Review submitted!"]);
        } catch (\PDOException $e) {
            http_response_code(409);
            echo json_encode(["message" => "You have already reviewed this venue"]);
        }
    }

    private function allowVenueReview(PDO $db): void {
        try {
            $db->exec("ALTER TABLE reviews MODIFY booking_id INT NULL");
        } catch (\PDOException $e) {}
    }

    // PUT /api/reviews/:id/reply  { reply }
    public function reply($id) {
        $authUser = Auth::require();
        $owner_id = (int)$authUser['id'];
        $data     = json_decode(file_get_contents("php://input"));
        $reply    = htmlspecialchars(strip_tags(trim($data->reply ?? '')));
        if (!$id || !$reply) {
            http_response_code(400); echo json_encode(['message' => 'reply required']); return;
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
