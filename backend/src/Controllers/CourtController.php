<?php

require_once __DIR__ . '/../Models/Court.php';
require_once __DIR__ . '/../Models/Booking.php';

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
        $radius    = isset($_GET['radius'])    ? (int)$_GET['radius']    : 25;
        $adminList = !empty($_GET['admin_list']);
        if ($adminList) {
            Auth::requireAdmin();
        }

        $court = new Court();
        $stmt  = $court->read($location, $type, $owner_id, $lat, $lng, $radius, $adminList);

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
                "image_url"           => self::normalizeImageUrl($row["image_url"]),
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
                "avg_rating"          => isset($row["avg_rating"]) && $row["avg_rating"] !== null ? round((float)$row["avg_rating"], 1) : null,
                "review_count"        => (int)($row["review_count"] ?? 0),
            ];
            // Include distance (km) when GPS search was used
            if (isset($row["distance"])) {
                $item["distance_km"] = round((float)$row["distance"], 1);
            }
            if ($adminList) {
                $item["claim_status"] = $row["claim_status"] ?? null;
            }
            $courts_arr["records"][] = $item;
        }
        http_response_code(200);
        echo json_encode($courts_arr);
    }

    // GET /api/courts/:id
    public function show($id) {
        $db   = Database::getConnection();
        $stmt = $db->prepare("
            SELECT c.*,
                   AVG(r.rating) AS avg_rating,
                   COUNT(r.id)   AS review_count
            FROM courts c
            LEFT JOIN reviews r ON r.court_id = c.id
            WHERE c.id = ?
            GROUP BY c.id
            LIMIT 1
        ");
        $stmt->execute([$id]);
        $row  = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) { http_response_code(404); echo json_encode(['message' => 'Not found']); return; }
        $row['amenities']    = $row['amenities'] ? json_decode($row['amenities'], true) : [];
        $row['avg_rating']   = $row['avg_rating']   !== null ? round((float)$row['avg_rating'], 1) : null;
        $row['review_count'] = (int)$row['review_count'];
        $row['image_url']    = self::normalizeImageUrl($row['image_url']);
        http_response_code(200);
        echo json_encode(['court' => $row]);
    }

    /**
     * GET /courts/available-at?date=YYYY-MM-DD&start=HH:MM&duration_minutes=60&lat=&lng=&radius=25
     * Public — courts near lat/lng with at least one bookable unit free for the window.
     */
    public function availableAt() {
        $date     = $_GET['date'] ?? '';
        $startT   = trim($_GET['start'] ?? '');
        $duration = max(15, min(24 * 60, (int)($_GET['duration_minutes'] ?? 60)));
        $lat      = isset($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng      = isset($_GET['lng']) ? (float)$_GET['lng'] : null;
        $radius   = isset($_GET['radius']) ? (int)$_GET['radius'] : 25;

        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid date — use YYYY-MM-DD']);
            return;
        }
        if ($startT === '' || !preg_match('/^\d{1,2}:\d{2}(:\d{2})?$/', $startT)) {
            http_response_code(400);
            echo json_encode(['message' => 'start is required — use HH:MM']);
            return;
        }
        if ($lat === null || $lng === null) {
            http_response_code(400);
            echo json_encode(['message' => 'lat and lng are required']);
            return;
        }

        if (strlen($startT) <= 5) {
            $startT .= ':00';
        }

        $start_dt = $date . ' ' . $startT;
        if (strtotime($start_dt) === false) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid datetime']);
            return;
        }
        $end_dt = date('Y-m-d H:i:s', strtotime($start_dt) + $duration * 60);

        $booking = new Booking();
        $court   = new Court();
        $stmt    = $court->read(null, 'All', null, $lat, $lng, $radius, false);

        $records = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            if (!$this->courtOpenForWindow($row, $start_dt, $end_dt)) {
                continue;
            }
            if (!$this->courtHasFreeSlot($booking, (int)$row['id'], $start_dt, $end_dt)) {
                continue;
            }
            $records[] = [
                'id'             => (int)$row['id'],
                'name'           => $row['name'],
                'type'           => $row['type'],
                'location'       => $row['location'],
                'hourly_rate'    => $row['hourly_rate'],
                'image_url'      => self::normalizeImageUrl($row['image_url']),
                'lat'            => $row['lat'],
                'lng'            => $row['lng'],
                'distance_km'    => isset($row['distance']) ? round((float)$row['distance'], 1) : null,
                'avg_rating'     => isset($row['avg_rating']) && $row['avg_rating'] !== null ? round((float)$row['avg_rating'], 1) : null,
                'review_count'   => (int)($row['review_count'] ?? 0),
            ];
        }

        http_response_code(200);
        echo json_encode([
            'window'  => ['start' => $start_dt, 'end' => $end_dt, 'duration_minutes' => $duration],
            'records' => $records,
        ]);
    }

    private function courtOpenForWindow(array $court, string $start_dt, string $end_dt): bool {
        $open  = substr($court['open_time'] ?? '06:00:00', 0, 8);
        $close = substr($court['close_time'] ?? '22:00:00', 0, 8);
        $t1    = date('H:i:s', strtotime($start_dt));
        $t2    = date('H:i:s', strtotime($end_dt));
        if (date('Y-m-d', strtotime($start_dt)) !== date('Y-m-d', strtotime($end_dt))) {
            return false;
        }
        if ($t2 <= $t1) {
            return false;
        }
        return $t1 >= $open && $t2 <= $close;
    }

    private function courtHasFreeSlot(Booking $booking, int $court_id, string $start_dt, string $end_dt): bool {
        $stmt = $booking->conn->prepare('SELECT id FROM sub_courts WHERE court_id = ? ORDER BY id');
        $stmt->execute([$court_id]);
        $ids = $stmt->fetchAll(PDO::FETCH_COLUMN);
        if (empty($ids)) {
            return $booking->isSlotAvailable($court_id, $start_dt, $end_dt, null);
        }
        foreach ($ids as $sid) {
            if ($booking->isSlotAvailable($court_id, $start_dt, $end_dt, (int)$sid)) {
                return true;
            }
        }
        return false;
    }

    // POST /api/courts
    public function create() {
        $authUser = Auth::requireOwner();
        $data     = json_decode(file_get_contents("php://input"));

        if (!empty($data->name) && !empty($data->hourly_rate)) {
            $court = new Court();
            $court->owner_id    = (int)$authUser['id']; // always from token
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

    // POST /courts/claim  { place_id, hourly_rate, description?, proof_url? }
    public function claim() {
        $authUser    = Auth::require();
        $owner_id    = (int)$authUser['id'];
        $data        = json_decode(file_get_contents("php://input"));
        $place_id    = (int)($data->place_id    ?? 0);
        $hourly_rate = (float)($data->hourly_rate ?? 0);
        $proof_url   = trim($data->proof_url ?? '');

        if (!$place_id || !$hourly_rate) {
            http_response_code(400);
            echo json_encode(['message' => 'place_id and hourly_rate are required']);
            return;
        }

        $db = Database::getConnection();

        // Ensure claim columns exist
        try { $db->exec("ALTER TABLE courts ADD COLUMN claim_status ENUM('pending','approved','rejected') NULL DEFAULT NULL"); } catch (Exception $e) {}
        try { $db->exec("ALTER TABLE courts ADD COLUMN claim_proof_url TEXT NULL"); } catch (Exception $e) {}
        try { $db->exec("ALTER TABLE courts ADD COLUMN claim_rejection_reason TEXT NULL"); } catch (Exception $e) {}

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

    // Rewrite localhost/dev image URLs to the production domain
    private static function normalizeImageUrl(?string $url): string {
        if (!$url) return '';
        if (strpos($url, 'localhost') !== false || strpos($url, '127.0.0.1') !== false) {
            if (preg_match('#/uploads/([^?#\s]+)$#', $url, $m)) {
                return 'https://www.kocourt.com/backend/uploads/' . $m[1];
            }
        }
        return $url;
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
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];
        $data     = json_decode(file_get_contents("php://input"));
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
        Auth::requireAdmin();
        $data     = json_decode(file_get_contents("php://input"));
        $verified = isset($data->is_verified) ? (int)$data->is_verified : 1;
        $db = Database::getConnection();
        $db->prepare("UPDATE courts SET is_verified=? WHERE id=?")->execute([$verified, $id]);
        http_response_code(200);
        echo json_encode(['message' => 'Court verification updated.', 'is_verified' => (bool)$verified]);
    }

    // DELETE /api/courts/:id
    public function delete($id) {
        $authUser = Auth::requireOwner();
        $owner_id = (int)$authUser['id'];
        $db  = Database::getConnection();
        $chk = $db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $chk->execute([$id, $owner_id]);
        if (!$chk->fetch()) { http_response_code(403); echo json_encode(['message' => 'Not authorised']); return; }
        $db->prepare("DELETE FROM courts WHERE id=? AND owner_id=?")->execute([$id, $owner_id]);
        http_response_code(200);
        echo json_encode(['message' => 'Court deleted.']);
    }
}
