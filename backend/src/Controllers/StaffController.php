<?php

class StaffController
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getConnection();
        $this->ensureTable();
    }

    private function ensureTable(): void
    {
        $this->db->exec("
            CREATE TABLE IF NOT EXISTS court_staff (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                court_id   INT NOT NULL,
                user_id    INT NOT NULL,
                added_by   INT NOT NULL,
                role       ENUM('manager','viewer') DEFAULT 'manager',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_court_user (court_id, user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }

    // GET /court-staff?court_id=X
    public function list(): void
    {
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];
        $court_id = (int)($_GET['court_id'] ?? 0);

        if (!$court_id) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id required']);
            return;
        }

        // Verify ownership
        $chk = $this->db->prepare("SELECT id FROM courts WHERE id = ? AND owner_id = ?");
        $chk->execute([$court_id, $owner_id]);
        if (!$chk->fetch()) {
            http_response_code(403); echo json_encode(['message' => 'Forbidden']); return;
        }

        $stmt = $this->db->prepare("
            SELECT cs.id, cs.role, cs.created_at,
                   u.id AS user_id, u.name, u.phone, u.avatar_url
            FROM court_staff cs
            JOIN users u ON u.id = cs.user_id
            WHERE cs.court_id = ?
            ORDER BY cs.created_at ASC
        ");
        $stmt->execute([$court_id]);
        echo json_encode(['staff' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // POST /court-staff  { court_id, phone, role? }
    public function add(): void
    {
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];
        $data     = json_decode(file_get_contents('php://input'));
        $court_id = (int)($data->court_id ?? 0);
        $phone    = trim($data->phone    ?? '');
        $role     = in_array($data->role ?? '', ['manager','viewer']) ? $data->role : 'manager';

        if (!$court_id || !$phone) {
            http_response_code(400);
            echo json_encode(['message' => 'court_id and phone required']);
            return;
        }

        // Verify ownership
        $chk = $this->db->prepare("SELECT id FROM courts WHERE id = ? AND owner_id = ?");
        $chk->execute([$court_id, $owner_id]);
        if (!$chk->fetch()) {
            http_response_code(403); echo json_encode(['message' => 'Forbidden']); return;
        }

        // Find user by phone
        $uStmt = $this->db->prepare("SELECT id, name, phone, avatar_url FROM users WHERE phone = ?");
        $uStmt->execute([$phone]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC);
        if (!$user) {
            http_response_code(404);
            echo json_encode(['message' => 'No KoCourt account found for this phone number']);
            return;
        }

        if ($user['id'] === $owner_id) {
            http_response_code(400);
            echo json_encode(['message' => 'You cannot add yourself as staff']);
            return;
        }

        try {
            $ins = $this->db->prepare("
                INSERT INTO court_staff (court_id, user_id, added_by, role) VALUES (?, ?, ?, ?)
            ");
            $ins->execute([$court_id, $user['id'], $owner_id, $role]);
            $newId = (int)$this->db->lastInsertId();

            echo json_encode([
                'message' => "{$user['name']} added as {$role}",
                'staff'   => [
                    'id'         => $newId,
                    'user_id'    => $user['id'],
                    'name'       => $user['name'],
                    'phone'      => $user['phone'],
                    'avatar_url' => $user['avatar_url'],
                    'role'       => $role,
                ],
            ]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                http_response_code(409);
                echo json_encode(['message' => "{$user['name']} is already staff for this court"]);
            } else {
                http_response_code(500);
                echo json_encode(['message' => 'Failed to add staff']);
            }
        }
    }

    // DELETE /court-staff/:id
    public function remove(int $id): void
    {
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];

        // Verify the record belongs to a court owned by this owner
        $chk = $this->db->prepare("
            SELECT cs.id FROM court_staff cs
            JOIN courts c ON c.id = cs.court_id
            WHERE cs.id = ? AND c.owner_id = ?
        ");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) {
            http_response_code(403); echo json_encode(['message' => 'Forbidden']); return;
        }

        $this->db->prepare("DELETE FROM court_staff WHERE id = ?")->execute([$id]);
        echo json_encode(['message' => 'Staff member removed']);
    }

    // GET /court-staff/my-courts
    // Returns courts + minimal court data where this user is staff
    public function myCourts(): void
    {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];

        $stmt = $this->db->prepare("
            SELECT cs.id AS staff_id, cs.role,
                   c.id, c.name, c.type, c.location, c.image_url, c.hourly_rate, c.owner_id,
                   u.name AS owner_name, u.phone AS owner_phone
            FROM court_staff cs
            JOIN courts c ON c.id = cs.court_id
            JOIN users  u ON u.id = c.owner_id
            WHERE cs.user_id = ?
            ORDER BY cs.created_at ASC
        ");
        $stmt->execute([$user_id]);
        echo json_encode(['courts' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }
}
