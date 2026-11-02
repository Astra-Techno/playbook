<?php

require_once __DIR__ . '/../CustomerDirectory.php';

class CustomerDirectoryController
{
    public function index(int $courtId): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $court = $db->prepare('SELECT id, owner_id FROM courts WHERE id = ?');
        $court->execute([$courtId]);
        $venue = $court->fetch(PDO::FETCH_ASSOC);
        if (!$venue) {
            http_response_code(404);
            echo json_encode(['message' => 'Venue not found']);
            return;
        }
        $staff = $db->prepare('SELECT role FROM court_staff WHERE court_id = ? AND user_id = ?');
        $staff->execute([$courtId, $userId]);
        $role = $staff->fetchColumn();
        $allowed = CustomerDirectory::canView(
            ($authUser['role'] ?? '') === 'admin',
            (int)$venue['owner_id'] === $userId,
            $role === false ? null : (string)$role
        );
        if (!$allowed) {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return;
        }
        $stmt = $db->prepare("
            SELECT u.id, u.name, COUNT(b.id) AS booking_count, MAX(b.start_time) AS last_played
            FROM bookings b
            JOIN users u ON u.id = b.user_id
            WHERE b.court_id = ? AND b.status = 'confirmed' AND b.user_id > 0
            GROUP BY u.id, u.name
            ORDER BY booking_count DESC, u.name
            LIMIT 100
        ");
        $stmt->execute([$courtId]);
        $customers = array_map([CustomerDirectory::class, 'row'], $stmt->fetchAll(PDO::FETCH_ASSOC));
        echo json_encode(['customers' => $customers]);
    }
}
