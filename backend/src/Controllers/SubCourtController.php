<?php

class SubCourtController
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
            CREATE TABLE IF NOT EXISTS sub_courts (
                id          INT AUTO_INCREMENT PRIMARY KEY,
                court_id    INT NOT NULL,
                name        VARCHAR(100) NOT NULL,
                description VARCHAR(255) DEFAULT NULL,
                hourly_rate DECIMAL(10,2) DEFAULT NULL,
                sort_order  INT DEFAULT 0,
                created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_court (court_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        // Add sub_court_id to bookings if missing
        try { $this->db->exec("ALTER TABLE bookings ADD COLUMN sub_court_id INT DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE bookings ADD COLUMN guest_name VARCHAR(100) DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE bookings ADD COLUMN guest_phone VARCHAR(20) DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE bookings ADD COLUMN notes TEXT DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE sub_courts ADD COLUMN image_url VARCHAR(500) DEFAULT NULL"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE sub_courts ADD COLUMN capacity INT DEFAULT 1"); } catch (Exception $e) {}
        try { $this->db->exec("ALTER TABLE sub_courts ADD COLUMN booking_mode VARCHAR(20) DEFAULT 'exclusive'"); } catch (Exception $e) {}
    }

    // GET /sub-courts/:id
    public function show(int $id): void
    {
        $stmt = $this->db->prepare("SELECT * FROM sub_courts WHERE id = ? LIMIT 1");
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) { http_response_code(404); echo json_encode(['message' => 'Not found']); return; }
        http_response_code(200);
        echo json_encode(['space' => $row]);
    }

    // GET /sub-courts?court_id=X
    public function index(): void
    {
        $court_id = (int)($_GET['court_id'] ?? 0);
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }
        $stmt = $this->db->prepare("SELECT * FROM sub_courts WHERE court_id = ? ORDER BY sort_order, id");
        $stmt->execute([$court_id]);
        echo json_encode(['sub_courts' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // POST /sub-courts  { court_id, owner_id, name, description?, hourly_rate? }
    public function create(): void
    {
        $data     = json_decode(file_get_contents('php://input'));
        $court_id = (int)($data->court_id ?? 0);
        $owner_id = (int)($data->owner_id ?? 0);
        $name     = trim($data->name ?? '');
        if (!$court_id || !$owner_id || !$name) {
            http_response_code(400); echo json_encode(['message' => 'court_id, owner_id and name required']); return;
        }
        $chk = $this->db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$court_id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }

        $capacity     = max(1, (int)($data->capacity ?? 1));
        $booking_mode = in_array($data->booking_mode ?? '', ['exclusive', 'shared']) ? $data->booking_mode : 'exclusive';

        $ins = $this->db->prepare("INSERT INTO sub_courts (court_id, name, description, hourly_rate, image_url, capacity, booking_mode) VALUES (?,?,?,?,?,?,?)");
        $ins->execute([
            $court_id, $name,
            trim($data->description ?? '') ?: null,
            isset($data->hourly_rate) && $data->hourly_rate !== '' ? (float)$data->hourly_rate : null,
            trim($data->image_url ?? '') ?: null,
            $capacity,
            $booking_mode,
        ]);
        $newId = (int)$this->db->lastInsertId();
        $row   = $this->db->prepare("SELECT * FROM sub_courts WHERE id=?");
        $row->execute([$newId]);
        http_response_code(201);
        echo json_encode(['message' => 'Sub-court created', 'sub_court' => $row->fetch(PDO::FETCH_ASSOC)]);
    }

    // PUT /sub-courts/:id  { owner_id, name?, description?, hourly_rate? }
    public function update(int $id): void
    {
        $data     = json_decode(file_get_contents('php://input'));
        $owner_id = (int)($data->owner_id ?? 0);
        $chk = $this->db->prepare("SELECT sc.id FROM sub_courts sc JOIN courts c ON c.id=sc.court_id WHERE sc.id=? AND c.owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }

        $fields = []; $vals = [];
        if (isset($data->name))        { $fields[] = 'name=?';        $vals[] = trim($data->name); }
        if (isset($data->description)) { $fields[] = 'description=?'; $vals[] = trim($data->description) ?: null; }
        if (isset($data->hourly_rate)) { $fields[] = 'hourly_rate=?'; $vals[] = $data->hourly_rate !== '' ? (float)$data->hourly_rate : null; }
        if (isset($data->image_url))   { $fields[] = 'image_url=?';   $vals[] = trim($data->image_url) ?: null; }
        if (isset($data->capacity))    { $fields[] = 'capacity=?';    $vals[] = max(1, (int)$data->capacity); }
        if (isset($data->booking_mode)){ $fields[] = 'booking_mode=?';$vals[] = in_array($data->booking_mode, ['exclusive','shared']) ? $data->booking_mode : 'exclusive'; }
        if ($fields) { $vals[] = $id; $this->db->prepare("UPDATE sub_courts SET ".implode(',',$fields)." WHERE id=?")->execute($vals); }
        echo json_encode(['message' => 'Updated']);
    }

    // DELETE /sub-courts/:id  { owner_id }
    public function delete(int $id): void
    {
        $data     = json_decode(file_get_contents('php://input'));
        $owner_id = (int)($data->owner_id ?? 0);
        $chk = $this->db->prepare("SELECT sc.id FROM sub_courts sc JOIN courts c ON c.id=sc.court_id WHERE sc.id=? AND c.owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Forbidden']); return; }
        $this->db->prepare("DELETE FROM sub_courts WHERE id=?")->execute([$id]);
        echo json_encode(['message' => 'Deleted']);
    }
}
