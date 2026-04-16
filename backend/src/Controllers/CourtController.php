<?php

require_once __DIR__ . '/../Models/Court.php';

class CourtController {

    // GET /api/courts?lat=12.9&lng=80.2          ← GPS proximity (25 km radius)
    // GET /api/courts?location=Chennai&type=turf  ← text search fallback
    // GET /api/courts?owner_id=3                  ← owner's own courts
    public function index() {
        $location = isset($_GET['location']) ? trim($_GET['location']) : null;
        $type     = isset($_GET['type'])     ? trim($_GET['type'])     : null;
        $owner_id = isset($_GET['owner_id']) ? (int)$_GET['owner_id'] : null;
        $lat      = isset($_GET['lat'])      ? (float)$_GET['lat']    : null;
        $lng      = isset($_GET['lng'])      ? (float)$_GET['lng']    : null;
        $radius   = isset($_GET['radius'])   ? (int)$_GET['radius']   : 25;

        $court = new Court();
        $stmt  = $court->read($location, $type, $owner_id, $lat, $lng, $radius);

        $courts_arr = ["records" => []];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $item = [
                "id"                  => $row["id"],
                "owner_id"            => $row["owner_id"],
                "name"                => $row["name"],
                "type"                => $row["type"],
                "description"         => $row["description"],
                "location"            => $row["location"],
                "hourly_rate"         => $row["hourly_rate"],
                "image_url"           => $row["image_url"],
                "lat"                 => $row["lat"],
                "lng"                 => $row["lng"],
                "open_time"           => $row["open_time"]           ?? "06:00:00",
                "close_time"          => $row["close_time"]          ?? "22:00:00",
                "morning_peak_start"  => $row["morning_peak_start"]  ?? "05:00:00",
                "morning_peak_end"    => $row["morning_peak_end"]    ?? "09:00:00",
                "evening_peak_start"  => $row["evening_peak_start"]  ?? "17:00:00",
                "evening_peak_end"    => $row["evening_peak_end"]    ?? "21:00:00",
                "peak_members_only"   => (bool)($row["peak_members_only"] ?? false),
                "amenities"           => $row["amenities"] ? json_decode($row["amenities"], true) : [],
                "is_verified"         => (bool)($row["is_verified"] ?? false),
            ];
            // Include distance (km) when GPS search was used
            if (isset($row["distance"])) {
                $item["distance_km"] = round((float)$row["distance"], 1);
            }
            $courts_arr["records"][] = $item;
        }
        http_response_code(200);
        echo json_encode($courts_arr);
    }

    // GET /api/courts/:id
    public function show($id) {
        $db   = Database::getConnection();
        $stmt = $db->prepare("SELECT * FROM courts WHERE id = ? LIMIT 1");
        $stmt->execute([$id]);
        $row  = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) { http_response_code(404); echo json_encode(['message' => 'Not found']); return; }
        $row['amenities'] = $row['amenities'] ? json_decode($row['amenities'], true) : [];
        http_response_code(200);
        echo json_encode(['court' => $row]);
    }

    // POST /api/courts
    public function create() {
        $data = json_decode(file_get_contents("php://input"));

        if (!empty($data->owner_id) && !empty($data->name) && !empty($data->hourly_rate)) {
            $court = new Court();
            $court->owner_id    = $data->owner_id;
            $court->name        = $data->name;
            $court->type        = $data->type        ?? 'other';
            $court->description = $data->description ?? '';
            $court->location    = $data->location    ?? '';
            $court->hourly_rate = $data->hourly_rate;
            $court->image_url   = $data->image_url   ?? '';
            $court->lat                 = isset($data->lat)  ? (float)$data->lat : null;
            $court->lng                 = isset($data->lng)  ? (float)$data->lng : null;
            $court->open_time           = $data->open_time          ?? '06:00:00';
            $court->close_time          = $data->close_time         ?? '22:00:00';
            $court->morning_peak_start  = $data->morning_peak_start ?? '05:00:00';
            $court->morning_peak_end    = $data->morning_peak_end   ?? '09:00:00';
            $court->evening_peak_start  = $data->evening_peak_start ?? '17:00:00';
            $court->evening_peak_end    = $data->evening_peak_end   ?? '21:00:00';
            $court->peak_members_only   = !empty($data->peak_members_only) ? 1 : 0;
            $court->amenities           = isset($data->amenities) ? json_encode($data->amenities) : null;

            if ($court->create()) {
                $db    = Database::getConnection();
                $newId = (int)$db->lastInsertId();
                if ($newId && $court->lat && $court->lng) {
                    $this->autoLinkPlace($newId, (float)$court->lat, (float)$court->lng, (string)$court->name, $db);
                }
                http_response_code(201);
                echo json_encode(["message" => "Court was created.", "id" => $newId]);
            } else {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create court."]);
            }
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Data is incomplete."]);
        }
    }

    // POST /courts/claim  { owner_id, place_id, hourly_rate, description?, proof_url? }
    public function claim() {
        $data        = json_decode(file_get_contents("php://input"));
        $owner_id    = (int)($data->owner_id    ?? 0);
        $place_id    = (int)($data->place_id    ?? 0);
        $hourly_rate = (float)($data->hourly_rate ?? 0);
        $proof_url   = trim($data->proof_url ?? '');

        if (!$owner_id || !$place_id || !$hourly_rate) {
            http_response_code(400);
            echo json_encode(['message' => 'owner_id, place_id and hourly_rate are required']);
            return;
        }

        $db = Database::getConnection();

        // Ensure claim columns exist
        try {
            $db->exec("ALTER TABLE courts
                ADD COLUMN claim_status ENUM('pending','approved','rejected') NULL DEFAULT NULL AFTER peak_members_only,
                ADD COLUMN claim_proof_url TEXT NULL AFTER claim_status,
                ADD COLUMN claim_rejection_reason TEXT NULL AFTER claim_proof_url");
        } catch (Exception $e) { /* columns already exist */ }

        // Fetch the ghost place (allow re-claim only if previous court was rejected)
        $stmt = $db->prepare(
            "SELECT p.*, c.id as existing_court_id, c.claim_status as existing_status
             FROM places p
             LEFT JOIN courts c ON c.id = p.court_id
             WHERE p.id = ?"
        );
        $stmt->execute([$place_id]);
        $place = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$place) {
            http_response_code(404);
            echo json_encode(['message' => 'Venue not found']);
            return;
        }

        // Block if already claimed (pending or approved)
        if ($place['existing_court_id'] && in_array($place['existing_status'], ['pending', 'approved'])) {
            http_response_code(409);
            $msg = $place['existing_status'] === 'approved'
                ? 'This venue has already been claimed and approved.'
                : 'A claim for this venue is already under review.';
            echo json_encode(['message' => $msg]);
            return;
        }

        // Create court — starts as pending (hidden from public listings)
        $court              = new Court();
        $court->owner_id    = $owner_id;
        $court->name        = $place['name'];
        $court->type        = $place['type']    ?? 'other';
        $court->location    = $place['address'] ?? '';
        $court->lat         = $place['lat']     ?? null;
        $court->lng         = $place['lng']     ?? null;
        $court->image_url   = $place['photo_reference'] ?? '';
        $court->hourly_rate = $hourly_rate;
        $court->description = trim($data->description ?? '');
        $court->open_time         = '06:00:00';
        $court->close_time        = '22:00:00';
        $court->morning_peak_start = '05:00:00';
        $court->morning_peak_end   = '09:00:00';
        $court->evening_peak_start = '17:00:00';
        $court->evening_peak_end   = '21:00:00';
        $court->peak_members_only  = 0;
        $court->amenities          = null;

        if (!$court->create()) {
            http_response_code(503);
            echo json_encode(['message' => 'Failed to create court']);
            return;
        }

        $newId = (int)$db->lastInsertId();

        // Set claim_status = pending + proof url
        $db->prepare("UPDATE courts SET claim_status = 'pending', claim_proof_url = ? WHERE id = ?")
           ->execute([$proof_url ?: null, $newId]);

        // Link place to this court (but NOT mark as 'onboarded' yet — wait for approval)
        $db->prepare("UPDATE places SET status = 'contacted', court_id = ? WHERE id = ?")
           ->execute([$newId, $place_id]);

        // Fetch user (role not yet upgraded — happens on approval)
        $uStmt = $db->prepare("SELECT id, name, phone, role, avatar_url, bio, skill_level, sport_preferences FROM users WHERE id = ?");
        $uStmt->execute([$owner_id]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC);

        http_response_code(201);
        echo json_encode([
            'message'   => 'Claim submitted! Our team will verify and approve within 24–48 hours.',
            'court_id'  => $newId,
            'status'    => 'pending',
            'user'      => $user,
        ]);
    }

    // GET  /courts/claims?admin_id=X
    // PUT  /courts/claims/:id/approve { admin_id }
    // PUT  /courts/claims/:id/reject  { admin_id, reason }
    public function listClaims() {
        $db = Database::getConnection();
        $stmt = $db->query(
            "SELECT c.id, c.name, c.type, c.location, c.hourly_rate,
                    c.claim_status, c.claim_proof_url, c.claim_rejection_reason,
                    c.created_at, c.owner_id,
                    u.name AS owner_name, u.phone AS owner_phone, u.avatar_url AS owner_avatar
             FROM courts c
             JOIN users u ON u.id = c.owner_id
             WHERE c.claim_status IS NOT NULL
             ORDER BY FIELD(c.claim_status,'pending','rejected','approved'), c.created_at DESC"
        );
        echo json_encode(['claims' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    public function approveClaim($court_id) {
        $data     = json_decode(file_get_contents("php://input"));
        $admin_id = (int)($data->admin_id ?? 0);
        $db = Database::getConnection();

        // Verify requester is admin
        $aStmt = $db->prepare("SELECT role FROM users WHERE id = ?");
        $aStmt->execute([$admin_id]);
        $admin = $aStmt->fetch(PDO::FETCH_ASSOC);
        if (!$admin || $admin['role'] !== 'admin') {
            http_response_code(403); echo json_encode(['message' => 'Not authorised']); return;
        }

        // Get court + owner
        $cStmt = $db->prepare("SELECT owner_id, claim_status FROM courts WHERE id = ?");
        $cStmt->execute([$court_id]);
        $court = $cStmt->fetch(PDO::FETCH_ASSOC);
        if (!$court) { http_response_code(404); echo json_encode(['message' => 'Court not found']); return; }

        // Approve: update court status, upgrade owner role, mark place onboarded
        $db->prepare("UPDATE courts SET claim_status = 'approved' WHERE id = ?")
           ->execute([$court_id]);
        $db->prepare("UPDATE users SET role = 'owner' WHERE id = ? AND role = 'player'")
           ->execute([$court['owner_id']]);
        $db->prepare("UPDATE places SET status = 'onboarded' WHERE court_id = ?")
           ->execute([$court_id]);

        http_response_code(200);
        echo json_encode(['message' => 'Claim approved. Court is now live.']);
    }

    public function rejectClaim($court_id) {
        $data     = json_decode(file_get_contents("php://input"));
        $admin_id = (int)($data->admin_id ?? 0);
        $reason   = trim($data->reason ?? 'Claim rejected by admin.');
        $db = Database::getConnection();

        $aStmt = $db->prepare("SELECT role FROM users WHERE id = ?");
        $aStmt->execute([$admin_id]);
        $admin = $aStmt->fetch(PDO::FETCH_ASSOC);
        if (!$admin || $admin['role'] !== 'admin') {
            http_response_code(403); echo json_encode(['message' => 'Not authorised']); return;
        }

        $db->prepare("UPDATE courts SET claim_status = 'rejected', claim_rejection_reason = ? WHERE id = ?")
           ->execute([$reason, $court_id]);
        // Free up the place for re-claiming
        $db->prepare("UPDATE places SET status = 'pending', court_id = NULL WHERE court_id = ?")
           ->execute([$court_id]);

        http_response_code(200);
        echo json_encode(['message' => 'Claim rejected.']);
    }

    // Auto-link newly created court to a nearby ghost place (within ~200 m)
    private function autoLinkPlace(int $courtId, float $lat, float $lng, string $courtName, PDO $db): void
    {
        // 0.002 deg ≈ 200 m
        $delta = 0.002;
        $stmt  = $db->prepare(
            "SELECT id FROM places
             WHERE status IN ('unregistered','contacted')
               AND court_id IS NULL
               AND lat BETWEEN ? AND ?
               AND lng BETWEEN ? AND ?
             ORDER BY request_count DESC
             LIMIT 1"
        );
        $stmt->execute([$lat - $delta, $lat + $delta, $lng - $delta, $lng + $delta]);
        $place = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$place) return;

        $placeId = (int)$place['id'];

        // Link and mark onboarded
        $db->prepare(
            "UPDATE places SET court_id = ?, status = 'onboarded', updated_at = NOW() WHERE id = ?"
        )->execute([$courtId, $placeId]);

        // Get all interested user IDs
        $uStmt = $db->prepare("SELECT user_id FROM service_requests WHERE place_id = ?");
        $uStmt->execute([$placeId]);
        $userIds = $uStmt->fetchAll(PDO::FETCH_COLUMN);

        if (empty($userIds)) return;

        // Ensure user_notifications table exists
        $db->exec("
            CREATE TABLE IF NOT EXISTS user_notifications (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                user_id    INT          NOT NULL,
                type       VARCHAR(50)  NOT NULL,
                title      VARCHAR(255) NOT NULL,
                body       TEXT,
                court_id   INT          DEFAULT NULL,
                read_at    DATETIME     DEFAULT NULL,
                created_at DATETIME     DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");

        $nStmt = $db->prepare(
            "INSERT INTO user_notifications (user_id, type, title, body, court_id)
             VALUES (?, 'venue_live', ?, ?, ?)"
        );
        foreach ($userIds as $uid) {
            $nStmt->execute([
                (int)$uid,
                'A venue you requested is now on KoCourt!',
                "{$courtName} is now available for booking.",
                $courtId,
            ]);
        }
    }

    // PUT /api/courts/:id
    public function update($id) {
        $data     = json_decode(file_get_contents("php://input"));
        $owner_id = (int)($data->owner_id ?? 0);
        if (!$id || !$owner_id) { http_response_code(400); echo json_encode(['message' => 'id and owner_id required']); return; }
        $db   = Database::getConnection();
        $chk  = $db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Not authorised']); return; }
        $db->prepare("UPDATE courts SET
            name=?, type=?, description=?, location=?, hourly_rate=?, image_url=?,
            lat=?, lng=?, open_time=?, close_time=?,
            morning_peak_start=?, morning_peak_end=?,
            evening_peak_start=?, evening_peak_end=?, peak_members_only=?,
            amenities=?
            WHERE id=? AND owner_id=?")->execute([
            $data->name        ?? '', $data->type        ?? 'other',
            $data->description ?? '', $data->location    ?? '',
            $data->hourly_rate ?? 0,  $data->image_url   ?? '',
            isset($data->lat)  ? (float)$data->lat  : null,
            isset($data->lng)  ? (float)$data->lng  : null,
            $data->open_time          ?? '06:00:00',
            $data->close_time         ?? '22:00:00',
            $data->morning_peak_start ?? '05:00:00',
            $data->morning_peak_end   ?? '09:00:00',
            $data->evening_peak_start ?? '17:00:00',
            $data->evening_peak_end   ?? '21:00:00',
            !empty($data->peak_members_only) ? 1 : 0,
            isset($data->amenities) ? json_encode($data->amenities) : null,
            $id, $owner_id
        ]);
        http_response_code(200);
        echo json_encode(['message' => 'Court updated.']);
    }

    // PUT /api/courts/:id/verify
    public function verify($id) {
        $data     = json_decode(file_get_contents("php://input"));
        $admin_id = (int)($data->admin_id ?? 0);
        $verified = isset($data->is_verified) ? (int)$data->is_verified : 1;
        $db = Database::getConnection();
        $chk = $db->prepare("SELECT id FROM users WHERE id=? AND role='admin'");
        $chk->execute([$admin_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Not authorised']); return; }
        $db->prepare("UPDATE courts SET is_verified=? WHERE id=?")->execute([$verified, $id]);
        http_response_code(200);
        echo json_encode(['message' => 'Court verification updated.', 'is_verified' => (bool)$verified]);
    }

    // DELETE /api/courts/:id  body: { owner_id }
    public function delete($id) {
        $data     = json_decode(file_get_contents("php://input"));
        $owner_id = (int)($data->owner_id ?? 0);
        if (!$id || !$owner_id) { http_response_code(400); echo json_encode(['message' => 'id and owner_id required']); return; }
        $db  = Database::getConnection();
        $chk = $db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Not authorised']); return; }
        $db->prepare("DELETE FROM courts WHERE id=? AND owner_id=?")->execute([$id, $owner_id]);
        http_response_code(200);
        echo json_encode(['message' => 'Court deleted.']);
    }
}
