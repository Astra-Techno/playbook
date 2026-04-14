<?php

class PlacesController
{
    private PDO    $db;
    private string $apiKey;
    private string $alertEmail;

    // Free tier: $200/month credit. Each Nearby Search = $0.032 (Basic fields are FREE with New API)
    // We make 2 calls per location. Hard stop at 6,000 calls/month to stay within free $200 credit.
    private const QUOTA_LIMIT = 6000;
    private const QUOTA_ALERT = 5500; // send alert email at 5,500 calls

    private const FALLBACK_IMAGES = [
        'shuttle'  => 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
        'turf'     => 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
        'gym'      => 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
        'cricket'  => 'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
        'tennis'   => 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
        'basket'   => 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
        'swimming' => 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
        'boxing'   => 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
        'dance'    => 'https://images.unsplash.com/photo-1547153760-18fc86324498?w=600&q=80',
        'other'    => 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80',
    ];

    public function __construct()
    {
        $this->db         = Database::getConnection();
        $this->apiKey     = getenv('GOOGLE_PLACES_API_KEY')    ?: '';
        $this->alertEmail = getenv('GOOGLE_QUOTA_ALERT_EMAIL') ?: '';
        $this->ensureTables();
    }

    // ── GET /nearby-places?lat=&lng=&user_id= ────────────────────────────────

    public function nearby(): void
    {
        $lat    = isset($_GET['lat'])     ? (float)$_GET['lat']   : null;
        $lng    = isset($_GET['lng'])     ? (float)$_GET['lng']   : null;
        $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : null;

        if ($lat === null || $lng === null) {
            http_response_code(400);
            echo json_encode(['error' => 'lat and lng are required']);
            return;
        }

        $places = $this->getFromCache($lat, $lng);

        if (empty($places)) {
            if ($this->hasApiKey() && !$this->isQuotaExceeded()) {
                $raw = $this->fetchFromGoogle($lat, $lng);
                if (!empty($raw)) {
                    $this->storePlaces($raw);
                    $places = $this->getFromCache($lat, $lng);
                }
            }
        }

        $requestedIds = $userId ? $this->getUserRequestedIds($userId) : [];

        foreach ($places as &$p) {
            $p['image_url']      = self::FALLBACK_IMAGES[$p['type']] ?? self::FALLBACK_IMAGES['other'];
            $p['user_requested'] = in_array((int)$p['id'], $requestedIds, true);
            unset($p['photo_reference']);
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

        $check = $this->db->prepare("SELECT id, request_count, status FROM places WHERE id = ?");
        $check->execute([$placeId]);
        $place = $check->fetch(PDO::FETCH_ASSOC);
        if (!$place) {
            http_response_code(404);
            echo json_encode(['error' => 'Place not found']);
            return;
        }

        $stmt = $this->db->prepare("INSERT IGNORE INTO service_requests (place_id, user_id) VALUES (?, ?)");
        $stmt->execute([$placeId, $userId]);
        $inserted = $stmt->rowCount() > 0;

        if ($inserted) {
            $this->db->prepare("UPDATE places SET request_count = request_count + 1 WHERE id = ?")->execute([$placeId]);
        }

        $countRow = $this->db->prepare("SELECT request_count FROM places WHERE id = ?");
        $countRow->execute([$placeId]);
        $count = (int)$countRow->fetchColumn();

        if ($inserted && $count >= 5 && $place['status'] === 'unregistered') {
            $this->db->prepare("UPDATE places SET status = 'contacted' WHERE id = ? AND status = 'unregistered'")->execute([$placeId]);
        }

        echo json_encode(['success' => true, 'requested' => true, 'request_count' => $count]);
    }

    // ── Admin: GET /admin/demand ─────────────────────────────────────────────

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
            $p['image_url'] = self::FALLBACK_IMAGES[$p['type']] ?? self::FALLBACK_IMAGES['other'];
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

    // ── Google Places API (New) ───────────────────────────────────────────────

    private function hasApiKey(): bool
    {
        return !empty($this->apiKey) && $this->apiKey !== 'your_google_places_api_key';
    }

    private function fetchFromGoogle(float $lat, float $lng): array
    {
        $endpoint = 'https://places.googleapis.com/v1/places:searchNearby';
        $headers  = [
            'Content-Type: application/json',
            'X-Goog-Api-Key: ' . $this->apiKey,
            // Basic tier fields only — free of charge
            'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,places.types,places.internationalPhoneNumber,places.websiteUri,places.rating',
        ];

        $seen = [];
        $out  = [];

        // Two calls: general sports venues + specific court types
        $typeBatches = [
            ['sports_complex', 'sports_club', 'stadium', 'gym', 'fitness_center', 'swimming_pool'],
            ['athletic_field', 'basketball_court', 'cricket_ground', 'tennis_court', 'volleyball_court', 'badminton_court', 'dance_studio'],
        ];

        foreach ($typeBatches as $types) {
            if ($this->isQuotaExceeded()) break;

            $body = json_encode([
                'includedTypes'       => $types,
                'locationRestriction' => [
                    'circle' => [
                        'center' => ['latitude' => $lat, 'longitude' => $lng],
                        'radius' => 10000.0,
                    ],
                ],
                'maxResultCount' => 20,
                'rankPreference' => 'DISTANCE',
            ]);

            $ch = curl_init($endpoint);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => $body,
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_USERAGENT      => 'KoCourt/1.0',
                CURLOPT_HTTPHEADER     => $headers,
            ]);
            $resp     = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            $this->incrementQuota(); // count every call regardless of result

            if ($httpCode !== 200 || !$resp) continue;

            $data = json_decode($resp, true);
            foreach ($data['places'] ?? [] as $r) {
                $placeId = $r['id'] ?? null;
                $name    = $r['displayName']['text'] ?? null;
                if (!$placeId || !$name || isset($seen[$placeId])) continue;
                $seen[$placeId] = true;

                $elLat = (float)($r['location']['latitude']  ?? 0);
                $elLng = (float)($r['location']['longitude'] ?? 0);
                if (!$elLat && !$elLng) continue;

                $out[] = [
                    'google_place_id' => $placeId,
                    'name'            => $name,
                    'type'            => $this->inferType($name, $r['types'] ?? []),
                    'address'         => $r['formattedAddress'] ?? '',
                    'lat'             => $elLat,
                    'lng'             => $elLng,
                    'phone'           => $r['internationalPhoneNumber'] ?? null,
                    'website'         => $r['websiteUri'] ?? null,
                    'rating'          => isset($r['rating']) ? (float)$r['rating'] : null,
                    'photo_reference' => null,
                    '_dist'           => $this->haversine($lat, $lng, $elLat, $elLng),
                ];
            }
        }

        usort($out, fn($a, $b) => $a['_dist'] <=> $b['_dist']);

        return array_map(function ($p) { unset($p['_dist']); return $p; }, $out);
    }

    // ── Quota tracking ───────────────────────────────────────────────────────

    private function isQuotaExceeded(): bool
    {
        $month = date('Y-m');
        $stmt  = $this->db->prepare("SELECT call_count FROM api_quota WHERE service = 'google_places' AND month = ?");
        $stmt->execute([$month]);
        return (int)$stmt->fetchColumn() >= self::QUOTA_LIMIT;
    }

    private function incrementQuota(): void
    {
        $month = date('Y-m');
        $this->db->prepare(
            "INSERT INTO api_quota (service, month, call_count) VALUES ('google_places', ?, 1)
             ON DUPLICATE KEY UPDATE call_count = call_count + 1"
        )->execute([$month]);

        // Check if we just crossed the alert threshold
        $stmt = $this->db->prepare(
            "SELECT call_count, alerted FROM api_quota WHERE service = 'google_places' AND month = ?"
        );
        $stmt->execute([$month]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($row && (int)$row['call_count'] >= self::QUOTA_ALERT && !(int)$row['alerted']) {
            $this->sendQuotaAlert((int)$row['call_count']);
            $this->db->prepare(
                "UPDATE api_quota SET alerted = 1 WHERE service = 'google_places' AND month = ?"
            )->execute([$month]);
        }
    }

    private function sendQuotaAlert(int $callCount): void
    {
        if (!$this->alertEmail) return;

        $remaining = self::QUOTA_LIMIT - $callCount;
        $month     = date('F Y');
        $subject   = "KoCourt Alert: Google Places API quota at {$callCount}/" . self::QUOTA_LIMIT;
        $message   = implode("\n", [
            "Google Places API Quota Alert",
            "==============================",
            "",
            "Month    : {$month}",
            "Used     : {$callCount} calls",
            "Limit    : " . self::QUOTA_LIMIT . " calls (free tier)",
            "Remaining: {$remaining} calls",
            "",
            "The API will automatically stop at " . self::QUOTA_LIMIT . " calls to prevent any charges.",
            "After that, demo venue data will be shown until next month.",
            "",
            "-- KoCourt System",
        ]);

        @mail(
            $this->alertEmail,
            $subject,
            $message,
            implode("\r\n", [
                'From: noreply@kocourt.com',
                'Content-Type: text/plain; charset=UTF-8',
            ])
        );
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private function inferType(string $name, array $types = []): string
    {
        $n = strtolower($name . ' ' . implode(' ', $types));

        if (strpos($n, 'badminton') !== false || strpos($n, 'shuttle') !== false || strpos($n, 'badminton_court') !== false) return 'shuttle';
        if (strpos($n, 'cricket')   !== false || strpos($n, 'cricket_ground') !== false)  return 'cricket';
        if (strpos($n, 'tennis')    !== false || strpos($n, 'tennis_court') !== false)     return 'tennis';
        if (strpos($n, 'swim')      !== false || strpos($n, 'pool') !== false || strpos($n, 'aqua') !== false || strpos($n, 'swimming_pool') !== false) return 'swimming';
        if (strpos($n, 'basket')    !== false || strpos($n, 'basketball_court') !== false) return 'basket';
        if (strpos($n, 'football')  !== false || strpos($n, 'turf') !== false || strpos($n, 'futsal') !== false || strpos($n, 'athletic_field') !== false) return 'turf';
        if (strpos($n, 'boxing')    !== false || strpos($n, 'martial') !== false || strpos($n, 'mma') !== false) return 'boxing';
        if (strpos($n, 'gym')       !== false || strpos($n, 'fitness') !== false || strpos($n, 'crossfit') !== false) return 'gym';
        if (strpos($n, 'dance')     !== false || strpos($n, 'zumba') !== false || strpos($n, 'dance_studio') !== false) return 'dance';

        return 'other';
    }

    private function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $r    = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a    = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    private function isAdmin(int $userId): bool
    {
        if (!$userId) return false;
        $stmt = $this->db->prepare("SELECT role FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        return $stmt->fetchColumn() === 'admin';
    }

    private function getFromCache(float $lat, float $lng): array
    {
        $delta = 0.09; // ~10 km
        $stmt  = $this->db->prepare(
            "SELECT * FROM places
             WHERE status IN ('unregistered','contacted')
               AND court_id IS NULL
               AND lat BETWEEN ? AND ?
               AND lng BETWEEN ? AND ?
               AND cached_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
             ORDER BY request_count DESC"
        );
        $stmt->execute([$lat - $delta, $lat + $delta, $lng - $delta, $lng + $delta]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function storePlaces(array $places): void
    {
        $stmt = $this->db->prepare(
            "INSERT INTO places
                (google_place_id, name, type, address, lat, lng, phone, website, rating, photo_reference, cached_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE
                name      = VALUES(name),
                address   = VALUES(address),
                phone     = COALESCE(VALUES(phone), phone),
                website   = COALESCE(VALUES(website), website),
                rating    = COALESCE(VALUES(rating), rating),
                cached_at = NOW()"
        );
        foreach ($places as $p) {
            $stmt->execute([
                $p['google_place_id'],
                $p['name'],
                $p['type'],
                $p['address'],
                $p['lat'],
                $p['lng'],
                $p['phone']           ?? null,
                $p['website']         ?? null,
                $p['rating']          ?? null,
                $p['photo_reference'] ?? null,
            ]);
        }
    }

    private function getUserRequestedIds(int $userId): array
    {
        $stmt = $this->db->prepare("SELECT place_id FROM service_requests WHERE user_id = ?");
        $stmt->execute([$userId]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
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

        $this->db->exec("
            CREATE TABLE IF NOT EXISTS api_quota (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                service    VARCHAR(50) NOT NULL,
                month      CHAR(7)     NOT NULL,
                call_count INT         NOT NULL DEFAULT 0,
                alerted    TINYINT(1)  NOT NULL DEFAULT 0,
                UNIQUE KEY uq_service_month (service, month)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }
}
