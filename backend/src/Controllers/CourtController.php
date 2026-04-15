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

    // POST /courts/claim  { owner_id, place_id, hourly_rate, description? }
    public function claim() {
        $data       = json_decode(file_get_contents("php://input"));
        $owner_id   = (int)($data->owner_id   ?? 0);
        $place_id   = (int)($data->place_id   ?? 0);
        $hourly_rate = (float)($data->hourly_rate ?? 0);

        if (!$owner_id || !$place_id || !$hourly_rate) {
            http_response_code(400);
            echo json_encode(['message' => 'owner_id, place_id and hourly_rate are required']);
            return;
        }

        $db = Database::getConnection();

        // Fetch the ghost place
        $stmt = $db->prepare("SELECT * FROM places WHERE id = ? AND (court_id IS NULL OR court_id = 0)");
        $stmt->execute([$place_id]);
        $place = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$place) {
            http_response_code(409);
            echo json_encode(['message' => 'Venue already claimed or not found']);
            return;
        }

        // Upgrade player to owner if needed
        $db->prepare("UPDATE users SET role = 'owner' WHERE id = ? AND role = 'player'")->execute([$owner_id]);

        // Create court from place data
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

        // Mark place as onboarded
        $db->prepare("UPDATE places SET status = 'onboarded', court_id = ? WHERE id = ?")
           ->execute([$newId, $place_id]);

        // Fetch refreshed user (role may have changed)
        $uStmt = $db->prepare("SELECT id, name, phone, role, avatar_url, bio, skill_level, sport_preferences FROM users WHERE id = ?");
        $uStmt->execute([$owner_id]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC);

        http_response_code(201);
        echo json_encode(['message' => 'Venue claimed successfully!', 'court_id' => $newId, 'user' => $user]);
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
