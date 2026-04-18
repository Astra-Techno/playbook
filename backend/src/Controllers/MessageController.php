<?php

require_once __DIR__ . '/../../config/database.php';

class MessageController {

    // GET /api/messages?booking_id=X
    // Returns messages for a booking thread; marks received messages as read
    public function index() {
        $authUser   = Auth::require();
        $user_id    = (int)$authUser['id'];
        $booking_id = (int)($_GET['booking_id'] ?? 0);
        if (!$booking_id) {
            http_response_code(400);
            echo json_encode(['message' => 'booking_id required']);
            return;
        }

        $db = Database::getConnection();

        // Mark messages sent to this user in this booking as read
        $db->prepare(
            "UPDATE messages SET is_read=1 WHERE booking_id=? AND receiver_id=? AND is_read=0"
        )->execute([$booking_id, $user_id]);

        $stmt = $db->prepare(
            "SELECT m.id, m.sender_id, m.receiver_id, m.body, m.is_read, m.created_at,
                    u.name AS sender_name, u.avatar_url AS sender_avatar
             FROM messages m
             JOIN users u ON u.id = m.sender_id
             WHERE m.booking_id = ?
             ORDER BY m.created_at ASC
             LIMIT 200"
        );
        $stmt->execute([$booking_id]);
        http_response_code(200);
        echo json_encode(['messages' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // GET /api/messages/threads
    // Returns one row per booking conversation the user participates in
    public function threads() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT b.id AS booking_id, b.start_time, c.id AS court_id, c.name AS court_name,
                    c.image_url AS court_image,
                    last_msg.body AS last_message, last_msg.created_at AS last_at,
                    unread.cnt AS unread_count,
                    other_user.id AS other_user_id, other_user.name AS other_user_name,
                    other_user.avatar_url AS other_user_avatar
             FROM bookings b
             JOIN courts c ON c.id = b.court_id
             -- Get last message in this booking
             JOIN (
                 SELECT booking_id, body, created_at
                 FROM messages
                 WHERE id IN (
                     SELECT MAX(id) FROM messages GROUP BY booking_id
                 )
             ) last_msg ON last_msg.booking_id = b.id
             -- Unread count for this user
             JOIN (
                 SELECT booking_id, COUNT(*) AS cnt
                 FROM messages
                 WHERE receiver_id = ? AND is_read = 0
                 GROUP BY booking_id
             ) unread ON unread.booking_id = b.id
             -- Other participant (sender or receiver that isn't this user)
             JOIN (
                 SELECT booking_id,
                        IF(sender_id = ?, receiver_id, sender_id) AS id
                 FROM messages
                 WHERE sender_id = ? OR receiver_id = ?
                 GROUP BY booking_id
             ) other ON other.booking_id = b.id
             JOIN users other_user ON other_user.id = other.id
             WHERE (b.user_id = ? OR c.owner_id = ?)
             ORDER BY last_msg.created_at DESC
             LIMIT 50"
        );
        $stmt->execute([$user_id, $user_id, $user_id, $user_id, $user_id, $user_id]);
        http_response_code(200);
        echo json_encode(['threads' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // GET /api/messages/unread-count
    public function unreadCount() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT COUNT(*) FROM messages WHERE receiver_id=? AND is_read=0"
        );
        $stmt->execute([$user_id]);
        echo json_encode(['count' => (int)$stmt->fetchColumn()]);
    }

    // POST /api/messages  { booking_id, receiver_id, body }
    public function create() {
        $authUser    = Auth::require();
        $sender_id   = (int)$authUser['id'];
        $data        = json_decode(file_get_contents('php://input'));
        $booking_id  = (int)($data->booking_id  ?? 0);
        $receiver_id = (int)($data->receiver_id ?? 0);
        $body        = htmlspecialchars(strip_tags(trim($data->body ?? '')));

        if (!$booking_id || !$receiver_id || !$body) {
            http_response_code(400);
            echo json_encode(['message' => 'booking_id, receiver_id, body required']);
            return;
        }

        $db = Database::getConnection();

        // Verify sender is part of this booking (player or court owner)
        $chk = $db->prepare(
            "SELECT b.id FROM bookings b
             JOIN courts c ON c.id = b.court_id
             WHERE b.id=? AND (b.user_id=? OR c.owner_id=?)"
        );
        $chk->execute([$booking_id, $sender_id, $sender_id]);
        if (!$chk->fetch()) {
            http_response_code(403);
            echo json_encode(['message' => 'Not authorised']);
            return;
        }

        $stmt = $db->prepare(
            "INSERT INTO messages (booking_id, sender_id, receiver_id, body) VALUES (?,?,?,?)"
        );
        $stmt->execute([$booking_id, $sender_id, $receiver_id, $body]);
        $newId = (int)$db->lastInsertId();

        // Push in-app notification to receiver
        $db->prepare(
            "INSERT INTO user_notifications (user_id, type, title, body)
             SELECT ?, 'message', CONCAT(u.name, ' sent you a message'), ?
             FROM users u WHERE u.id=?"
        )->execute([$receiver_id, substr($body, 0, 120), $sender_id]);

        http_response_code(201);
        echo json_encode(['message' => 'Sent.', 'id' => $newId]);
    }
}
