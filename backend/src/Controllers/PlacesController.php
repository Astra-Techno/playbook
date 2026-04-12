<?php

class PlacesController
{
    private PDO    $db;
    private string $apiKey;

    // Fallback Unsplash images per sport type (when no Google photo / no API key)
    private const FALLBACK_IMAGES = [
        'shuttle'  => 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
        'turf'     => 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
        'gym'      => 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
        'cricket'  => 'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
        'tennis'   => 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
        'basket'   => 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
        'swimming' => 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
        'boxing'   => 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
        'other'    => 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80',
    ];

    public function __construct()
    {
        $this->db     = Database::getConnection();
        $this->apiKey = getenv('GOOGLE_PLACES_API_KEY') ?: '';
        $this->ensureTables();
    }

    // ── GET /nearby-places?lat=&lng=&user_id= ────────────────────────────────

    public function nearby(): void
    {
        $lat    = isset($_GET['lat'])  ? (float)$_GET['lat']  : null;
        $lng    = isset($_GET['lng'])  ? (float)$_GET['lng']  : null;
        $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : null;

        if ($lat === null || $lng === null) {
            http_response_code(400);
            echo json_encode(['error' => 'lat and lng are required']);
            return;
        }

        // Try cache first (results within ~2 km fetched in last 24 h)
        $places = $this->getFromCache($lat, $lng);

        if (empty($places)) {
            $raw    = $this->isDemoMode() ? $this->getDemoPlaces($lat, $lng) : $this->fetchFromGoogle($lat, $lng);
            $this->storePlaces($raw);
            $places = $this->getFromCache($lat, $lng);
        }

        // Attach photo URL and user-request status
        $requestedIds = $userId ? $this->getUserRequestedIds($userId) : [];

        foreach ($places as &$p) {
            $p['image_url']       = $this->buildPhotoUrl($p['photo_reference'], $p['type']);
            $p['user_requested']  = in_array((int)$p['id'], $requestedIds, true);
        }
        unset($p);

        echo json_encode(['places' => array_values($places)]);
    }

    // ── POST /service-requests ───────────────────────────────────────────────

    public function requestService(): void
    {
        $data    = json_decode(file_get_contents('php://input'), true) ?? [];
        $placeId = (int)($data['place_id'] ?? 0);
        $userId  = (int)($data['user_id']  ?? 0);

        if (!$placeId || !$userId) {
            http_response_code(400);
            echo json_encode(['error' => 'place_id and user_id are required']);
            return;
        }

        // Verify place exists
        $check = $this->db->prepare("SELECT id, request_count, status FROM places WHERE id = ?");
        $check->execute([$placeId]);
        $place = $check->fetch(PDO::FETCH_ASSOC);
        if (!$place) {
            http_response_code(404);
            echo json_encode(['error' => 'Place not found']);
            return;
        }

        // Insert (ignore duplicate — user already requested)
        $stmt = $this->db->prepare(
            "INSERT IGNORE INTO service_requests (place_id, user_id) VALUES (?, ?)"
        );
        $stmt->execute([$placeId, $userId]);
        $inserted = $stmt->rowCount() > 0;

        if ($inserted) {
            $this->db->prepare(
                "UPDATE places SET request_count = request_count + 1 WHERE id = ?"
            )->execute([$placeId]);
        }

        // Fetch fresh count
        $countRow = $this->db->prepare("SELECT request_count FROM places WHERE id = ?");
        $countRow->execute([$placeId]);
        $count = (int)$countRow->fetchColumn();

        // Trigger outreach threshold check (5 requests)
        if ($inserted && $count >= 5 && $place['status'] === 'unregistered') {
            $this->flagForOutreach($placeId);
        }

        echo json_encode([
            'success'       => true,
            'requested'     => true,
            'request_count' => $count,
        ]);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    // ── Admin: GET /admin/demand?admin_id= ──────────────────────────────────

    public function adminDemand(): void
    {
        $adminId = (int)($_GET['admin_id'] ?? 0);
        if (!$this->isAdmin($adminId)) {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden']);
            return;
        }

        $stmt = $this->db->query(
            "SELECT p.*,
                    GROUP_CONCAT(u.name  ORDER BY sr.created_at SEPARATOR '||') AS requester_names,
                    GROUP_CONCAT(u.phone ORDER BY sr.created_at SEPARATOR '||') AS requester_phones,
                    GROUP_CONCAT(u.id    ORDER BY sr.created_at SEPARATOR ',')  AS requester_ids
             FROM places p
             LEFT JOIN service_requests sr ON sr.place_id = p.id
             LEFT JOIN users u             ON u.id = sr.user_id
             WHERE p.status IN ('unregistered','contacted')
             GROUP BY p.id
             ORDER BY p.request_count DESC, p.created_at DESC"
        );
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($rows as &$p) {
            $names  = $p['requester_names']  ? explode('||', $p['requester_names'])  : [];
            $phones = $p['requester_phones'] ? explode('||', $p['requester_phones']) : [];
            $ids    = $p['requester_ids']    ? array_map('intval', explode(',', $p['requester_ids'])) : [];

            $p['requesters'] = array_map(fn($i) => [
                'id'    => $ids[$i]    ?? null,
                'name'  => $names[$i]  ?? '',
                'phone' => $phones[$i] ?? '',
            ], array_keys($names));

            unset($p['requester_names'], $p['requester_phones'], $p['requester_ids']);
            $p['image_url'] = $this->buildPhotoUrl($p['photo_reference'], $p['type']);
        }
        unset($p);

        echo json_encode(['places' => array_values($rows)]);
    }

    // ── Admin: PUT /admin/places/:id/contact ─────────────────────────────────

    public function adminContact(int $id): void
    {
        $data    = json_decode(file_get_contents('php://input'), true) ?? [];
        $adminId = (int)($data['admin_id'] ?? 0);
        if (!$this->isAdmin($adminId)) {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden']);
            return;
        }

        $this->db->prepare(
            "UPDATE places SET status = 'contacted', updated_at = NOW() WHERE id = ? AND status = 'unregistered'"
        )->execute([$id]);

        echo json_encode(['success' => true]);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private function isAdmin(int $userId): bool
    {
        if (!$userId) return false;
        $stmt = $this->db->prepare("SELECT role FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        return $stmt->fetchColumn() === 'admin';
    }

    private function getFromCache(float $lat, float $lng): array
    {
        // 0.018 degrees ≈ 2 km; exclude already-onboarded places
        $delta = 0.018;
        $stmt  = $this->db->prepare(
            "SELECT * FROM places
             WHERE status IN ('unregistered','contacted')
               AND court_id IS NULL
               AND lat BETWEEN ? AND ?
               AND lng BETWEEN ? AND ?
               AND cached_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
             ORDER BY request_count DESC, rating DESC
             LIMIT 20"
        );
        $stmt->execute([$lat - $delta, $lat + $delta, $lng - $delta, $lng + $delta]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function fetchFromGoogle(float $lat, float $lng): array
    {
        $url = sprintf(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            . '?location=%s,%s&radius=5000&keyword=%s&key=%s',
            $lat,
            $lng,
            urlencode('sports court gym turf badminton cricket tennis swimming'),
            $this->apiKey
        );

        $ctx      = stream_context_create(['http' => ['timeout' => 8]]);
        $response = @file_get_contents($url, false, $ctx);
        if (!$response) return [];

        $data = json_decode($response, true);
        if (!isset($data['results'])) return [];

        $out  = [];
        $seen = [];
        foreach ($data['results'] as $r) {
            $pid = $r['place_id'] ?? null;
            if (!$pid || isset($seen[$pid])) continue;
            $seen[$pid] = true;

            $out[] = [
                'google_place_id' => $pid,
                'name'            => $r['name'] ?? 'Unknown Venue',
                'type'            => $this->inferType($r),
                'address'         => $r['vicinity'] ?? '',
                'lat'             => (float)($r['geometry']['location']['lat'] ?? $lat),
                'lng'             => (float)($r['geometry']['location']['lng'] ?? $lng),
                'phone'           => null,
                'rating'          => isset($r['rating']) ? (float)$r['rating'] : null,
                'photo_reference' => $r['photos'][0]['photo_reference'] ?? null,
            ];
        }

        return array_slice($out, 0, 15);
    }

    private function storePlaces(array $places): void
    {
        $stmt = $this->db->prepare(
            "INSERT INTO places
                (google_place_id, name, type, address, lat, lng, phone, rating, photo_reference, cached_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE
                name            = VALUES(name),
                address         = VALUES(address),
                lat             = VALUES(lat),
                lng             = VALUES(lng),
                rating          = VALUES(rating),
                photo_reference = VALUES(photo_reference),
                cached_at       = NOW()"
        );

        foreach ($places as $p) {
            $stmt->execute([
                $p['google_place_id'],
                $p['name'],
                $p['type'],
                $p['address'],
                $p['lat'],
                $p['lng'],
                $p['phone'] ?? null,
                $p['rating'] ?? null,
                $p['photo_reference'] ?? null,
            ]);
        }
    }

    private function getUserRequestedIds(int $userId): array
    {
        $stmt = $this->db->prepare(
            "SELECT place_id FROM service_requests WHERE user_id = ?"
        );
        $stmt->execute([$userId]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }

    private function buildPhotoUrl(?string $ref, string $type): string
    {
        if ($ref && $this->apiKey && !$this->isDemoMode()) {
            return sprintf(
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photo_reference=%s&key=%s',
                urlencode($ref),
                $this->apiKey
            );
        }
        return self::FALLBACK_IMAGES[$type] ?? self::FALLBACK_IMAGES['other'];
    }

    private function inferType(array $place): string
    {
        $types = $place['types'] ?? [];
        $name  = strtolower($place['name'] ?? '');

        if (in_array('gym', $types) || str_contains($name, 'gym') || str_contains($name, 'fitness') || str_contains($name, 'crossfit')) return 'gym';
        if (str_contains($name, 'badminton') || str_contains($name, 'shuttle')) return 'shuttle';
        if (str_contains($name, 'turf') || str_contains($name, 'football') || str_contains($name, 'soccer') || str_contains($name, 'futsal')) return 'turf';
        if (str_contains($name, 'cricket')) return 'cricket';
        if (str_contains($name, 'tennis')) return 'tennis';
        if (str_contains($name, 'swim') || str_contains($name, 'pool') || str_contains($name, 'aqua')) return 'swimming';
        if (str_contains($name, 'basketball') || str_contains($name, 'basket')) return 'basket';
        if (str_contains($name, 'boxing') || str_contains($name, 'martial') || str_contains($name, 'karate')) return 'boxing';
        if (in_array('stadium', $types) || in_array('sports_complex', $types)) return 'turf';
        return 'other';
    }

    private function flagForOutreach(int $placeId): void
    {
        // Mark as 'contacted' so we don't double-trigger
        $this->db->prepare(
            "UPDATE places SET status = 'contacted' WHERE id = ? AND status = 'unregistered'"
        )->execute([$placeId]);

        // TODO: trigger WhatsApp / SMS / email to places.phone or places.website owner
        // e.g. "X people near you want to book your facility on KoCourt. Join free at ..."
    }

    private function isDemoMode(): bool
    {
        return empty($this->apiKey)
            || $this->apiKey === 'your_google_places_api_key';
    }

    private function getDemoPlaces(float $lat, float $lng): array
    {
        return [
            ['google_place_id' => 'demo_p1', 'name' => 'City Badminton Academy',    'type' => 'shuttle',  'address' => '2.1 km away', 'lat' => $lat + 0.005, 'lng' => $lng + 0.003, 'phone' => null, 'rating' => 4.2, 'photo_reference' => null],
            ['google_place_id' => 'demo_p2', 'name' => 'FitZone Sports Club',       'type' => 'gym',      'address' => '1.4 km away', 'lat' => $lat - 0.004, 'lng' => $lng + 0.006, 'phone' => null, 'rating' => 4.5, 'photo_reference' => null],
            ['google_place_id' => 'demo_p3', 'name' => 'Green Turf Football Arena', 'type' => 'turf',     'address' => '3.0 km away', 'lat' => $lat + 0.008, 'lng' => $lng - 0.005, 'phone' => null, 'rating' => 4.0, 'photo_reference' => null],
            ['google_place_id' => 'demo_p4', 'name' => 'Victory Cricket Ground',    'type' => 'cricket',  'address' => '2.7 km away', 'lat' => $lat - 0.007, 'lng' => $lng - 0.004, 'phone' => null, 'rating' => 4.3, 'photo_reference' => null],
            ['google_place_id' => 'demo_p5', 'name' => 'AquaFit Swimming Centre',   'type' => 'swimming', 'address' => '1.8 km away', 'lat' => $lat + 0.002, 'lng' => $lng + 0.009, 'phone' => null, 'rating' => 4.1, 'photo_reference' => null],
            ['google_place_id' => 'demo_p6', 'name' => 'Smash Tennis Club',         'type' => 'tennis',   'address' => '3.5 km away', 'lat' => $lat - 0.010, 'lng' => $lng + 0.002, 'phone' => null, 'rating' => 4.4, 'photo_reference' => null],
        ];
    }

    private function ensureTables(): void
    {
        $this->db->exec("
            CREATE TABLE IF NOT EXISTS places (
                id               INT AUTO_INCREMENT PRIMARY KEY,
                google_place_id  VARCHAR(255)  NOT NULL UNIQUE,
                name             VARCHAR(255)  NOT NULL,
                type             VARCHAR(50)   DEFAULT 'other',
                address          TEXT,
                lat              DECIMAL(10,8),
                lng              DECIMAL(11,8),
                phone            VARCHAR(50),
                website          VARCHAR(500),
                rating           DECIMAL(3,1)  DEFAULT NULL,
                photo_reference  TEXT,
                status           ENUM('unregistered','contacted','onboarded') DEFAULT 'unregistered',
                court_id         INT           DEFAULT NULL,
                request_count    INT           DEFAULT 0,
                cached_at        DATETIME      DEFAULT CURRENT_TIMESTAMP,
                created_at       DATETIME      DEFAULT CURRENT_TIMESTAMP,
                updated_at       DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");

        $this->db->exec("
            CREATE TABLE IF NOT EXISTS service_requests (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                place_id   INT  NOT NULL,
                user_id    INT  NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_place_user (place_id, user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }
}
