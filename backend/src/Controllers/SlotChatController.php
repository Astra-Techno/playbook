<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../Push.php';

class SlotChatController {

    /**
     * GET /api/slot-chat/messages?court_id=X&date=Y&time=Z
     * Returns group messages for a specific court+date+time slot.
     * Only accessible by players who have a booking at that slot or the court owner.
     */
    public function messages() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $court_id  = (int)($_GET['court_id'] ?? 0);
        $slot_date = $_GET['date'] ?? '';
        $slot_time = $_GET['time'] ?? '';

        if (!$court_id || !$slot_date || !$slot_time) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id, date, and time required']);
            return;
        }

        $db = Database::getConnection();

        // Verify user is part of this slot (has a booking or is court owner)
        if (!$this->isSlotMember($db, $user_id, $court_id, $slot_date, $slot_time)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member of this slot']);
            return;
        }

        $stmt = $db->prepare(
            "SELECT sm.id, sm.sender_id, sm.body, sm.created_at,
                    u.name AS sender_name, u.avatar_url AS sender_avatar
             FROM slot_messages sm
             JOIN users u ON u.id = sm.sender_id
             WHERE sm.court_id = ? AND sm.slot_date = ? AND sm.slot_time = ?
             ORDER BY sm.created_at ASC
             LIMIT 500"
        );
        $stmt->execute([$court_id, $slot_date, $slot_time]);

        echo json_encode(['messages' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    /**
     * POST /api/slot-chat/messages  { court_id, date, time, body }
     * Send a message to the slot group chat.
     */
    public function send() {
        $authUser  = Auth::require();
        $sender_id = (int)$authUser['id'];
        $data      = json_decode(file_get_contents('php://input'));

        $court_id  = (int)($data->court_id ?? 0);
        $slot_date = trim($data->date ?? '');
        $slot_time = trim($data->time ?? '');
        $body      = htmlspecialchars(strip_tags(trim($data->body ?? '')));

        if (!$court_id || !$slot_date || !$slot_time || !$body) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id, date, time, body required']);
            return;
        }

        $db = Database::getConnection();

        if (!$this->isSlotMember($db, $sender_id, $court_id, $slot_date, $slot_time)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member of this slot']);
            return;
        }

        $stmt = $db->prepare(
            "INSERT INTO slot_messages (court_id, slot_date, slot_time, sender_id, body) VALUES (?,?,?,?,?)"
        );
        $stmt->execute([$court_id, $slot_date, $slot_time, $sender_id, $body]);
        $newId = (int)$db->lastInsertId();

        // Push notification to other slot members
        $senderName = $authUser['name'] ?? 'Someone';
        $members = $this->getSlotMembers($db, $court_id, $slot_date, $slot_time);
        foreach ($members as $memberId) {
            if ($memberId === $sender_id) continue;
            Push::sendToUser(
                $memberId,
                "Slot Chat: $senderName",
                $body,
                ['type' => 'slot_chat', 'court_id' => (string)$court_id, 'date' => $slot_date, 'time' => $slot_time]
            );
        }

        http_response_code(201);
        echo json_encode(['message' => 'Sent', 'id' => $newId]);
    }

    /**
     * GET /api/slot-chat/members?court_id=X&date=Y&time=Z
     * Returns all players booked at this slot + court owner.
     */
    public function members() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $court_id  = (int)($_GET['court_id'] ?? 0);
        $slot_date = $_GET['date'] ?? '';
        $slot_time = $_GET['time'] ?? '';

        if (!$court_id || !$slot_date || !$slot_time) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id, date, and time required']);
            return;
        }

        $db = Database::getConnection();

        if (!$this->isSlotMember($db, $user_id, $court_id, $slot_date, $slot_time)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member of this slot']);
            return;
        }

        // Get players with bookings at this slot
        $startDt = "$slot_date $slot_time";
        $stmt = $db->prepare(
            "SELECT DISTINCT u.id, u.name, u.avatar_url, u.skill_level,
                    'player' AS member_type
             FROM bookings b
             JOIN users u ON u.id = b.user_id
             WHERE b.court_id = ? AND b.start_time = ? AND b.status = 'confirmed'
             UNION
             SELECT u.id, u.name, u.avatar_url, u.skill_level,
                    'owner' AS member_type
             FROM courts c
             JOIN users u ON u.id = c.owner_id
             WHERE c.id = ?"
        );
        $stmt->execute([$court_id, $startDt, $court_id]);

        echo json_encode(['members' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    /**
     * GET /api/slot-chat/my-groups
     * Returns all active slot groups the user is part of (upcoming + today).
     */
    public function myGroups() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $db       = Database::getConnection();
        $today    = date('Y-m-d');

        // Step 1: Get distinct slots for this user
        $stmt = $db->prepare(
            "SELECT b.court_id,
                    DATE(b.start_time) AS slot_date,
                    TIME(b.start_time) AS slot_time,
                    MIN(TIME(b.end_time)) AS slot_end_time,
                    MIN(b.start_time) AS sort_key
             FROM bookings b
             WHERE b.user_id = ? AND b.status = 'confirmed'
               AND DATE(b.start_time) >= ?
             GROUP BY b.court_id, DATE(b.start_time), TIME(b.start_time)
             ORDER BY sort_key ASC
             LIMIT 50"
        );
        $stmt->execute([$user_id, $today]);
        $slots = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Step 2: Enrich each slot
        $groups = [];
        foreach ($slots as $s) {
            $cid = (int)$s['court_id'];
            $sd  = $s['slot_date'];
            $st  = $s['slot_time'];
            $startDt = "$sd $st";

            // Court info
            $ci = $db->prepare("SELECT name, image_url, type FROM courts WHERE id = ?");
            $ci->execute([$cid]);
            $court = $ci->fetch(PDO::FETCH_ASSOC) ?: [];

            // Player count
            $pc = $db->prepare("SELECT COUNT(DISTINCT user_id) FROM bookings WHERE court_id=? AND start_time=? AND status='confirmed'");
            $pc->execute([$cid, $startDt]);

            // Message count + last message
            $mc = $db->prepare("SELECT COUNT(*) FROM slot_messages WHERE court_id=? AND slot_date=? AND slot_time=?");
            $mc->execute([$cid, $sd, $st]);

            $lm = $db->prepare(
                "SELECT sm.body, u.name AS sender_name FROM slot_messages sm
                 JOIN users u ON u.id = sm.sender_id
                 WHERE sm.court_id=? AND sm.slot_date=? AND sm.slot_time=?
                 ORDER BY sm.id DESC LIMIT 1"
            );
            $lm->execute([$cid, $sd, $st]);
            $last = $lm->fetch(PDO::FETCH_ASSOC);

            $groups[] = [
                'court_id'         => $cid,
                'slot_date'        => $sd,
                'slot_time'        => $st,
                'slot_end_time'    => $s['slot_end_time'],
                'court_name'       => $court['name'] ?? '',
                'court_image'      => $court['image_url'] ?? '',
                'court_type'       => $court['type'] ?? '',
                'player_count'     => (int)$pc->fetchColumn(),
                'message_count'    => (int)$mc->fetchColumn(),
                'last_message'     => $last['body'] ?? null,
                'last_sender_name' => $last['sender_name'] ?? null,
            ];
        }

        echo json_encode(['groups' => $groups]);
    }

    // --- Helpers ---

    private function isSlotMember(PDO $db, int $userId, int $courtId, string $date, string $time): bool {
        $startDt = "$date $time";

        // Check if user has a booking at this slot
        $stmt = $db->prepare(
            "SELECT 1 FROM bookings
             WHERE court_id = ? AND user_id = ? AND start_time = ? AND status = 'confirmed'
             LIMIT 1"
        );
        $stmt->execute([$courtId, $userId, $startDt]);
        if ($stmt->fetch()) return true;

        // Check if user is the court owner
        $stmt = $db->prepare("SELECT 1 FROM courts WHERE id = ? AND owner_id = ?");
        $stmt->execute([$courtId, $userId]);
        return (bool)$stmt->fetch();
    }

    private function getSlotMembers(PDO $db, int $courtId, string $date, string $time): array {
        $startDt = "$date $time";
        $stmt = $db->prepare(
            "SELECT DISTINCT b.user_id FROM bookings b
             WHERE b.court_id = ? AND b.start_time = ? AND b.status = 'confirmed'
             UNION
             SELECT c.owner_id FROM courts c WHERE c.id = ?"
        );
        $stmt->execute([$courtId, $startDt, $courtId]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }
}
