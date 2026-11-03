<?php

require_once __DIR__ . '/../VenueAlert.php';

class VenueAlertController
{
    public function refresh(): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $now = (new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata')))->format('Y-m-d H:i:s');
        $until = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $now)->modify('+60 minutes')->format('Y-m-d H:i:s');
        $stmt = $db->prepare("
            SELECT b.id, b.court_id, b.start_time, b.end_time, b.status, b.attendance, b.guest_name, u.name AS player_name
            FROM bookings b
            INNER JOIN courts c ON c.id = b.court_id
            LEFT JOIN users u ON u.id = b.user_id AND b.user_id > 0
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND b.end_time > ? AND b.start_time <= ?
        ");
        $stmt->execute([$userId, $now, $until]);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $wanted = VenueAlert::keys($bookings);
        $existing = [];
        if ($wanted !== []) {
            $marks = implode(',', array_fill(0, count($wanted), '?'));
            $keys = $db->prepare("SELECT event_key FROM user_notifications WHERE user_id = ? AND event_key IN ($marks)");
            $keys->execute([$userId, ...$wanted]);
            foreach ($keys->fetchAll(PDO::FETCH_ASSOC) as $row) {
                $existing[] = (string)$row['event_key'];
            }
        }
        $plan = VenueAlert::plan($bookings, $existing, $now);
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $ins = $db->prepare("
            INSERT INTO user_notifications (user_id, type, title, body, court_id, event_key)
            VALUES (?, 'venue_alert', ?, ?, ?, ?)
        ");
        $saved = 0;
        foreach ($plan['alerts'] as $alert) {
            try {
                $ins->execute([$userId, $alert['title'], $alert['body'], $alert['court_id'], $alert['event_key']]);
                $saved++;
            } catch (PDOException $e) {
                $existing[] = $alert['event_key'];
            }
        }
        echo json_encode(['saved' => $saved]);
    }
}
