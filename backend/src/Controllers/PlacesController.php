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
        'yoga'     => 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=600&q=80',
        'martial'  => 'https://images.unsplash.com/photo-1555597673-b21d5c935865?w=600&q=80',
        'golf'     => 'https://images.unsplash.com/photo-1587174486073-ae5e5cff23aa?w=600&q=80',
        'bowling'  => 'https://images.unsplash.com/photo-1580542010967-f4e9b7a3b56f?w=600&q=80',
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
        // Dynamic data — never serve a stale browser-cached copy
        header('Cache-Control: no-store, no-cache, must-revalidate');

        $lat    = isset($_GET['lat'])     ? (float)$_GET['lat']   : null;
        $lng    = isset($_GET['lng'])     ? (float)$_GET['lng']   : null;
        $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : null;

        if ($lat === null || $lng === null) {
            http_response_code(400);
            echo json_encode(['error' => 'lat and lng are required']);
            return;
        }

        $places = $this->getFromCache($lat, $lng);

        // Re-fetch only when cache is empty (getFromCache already excludes entries older than 30 days)
        if (count($places) === 0 && $this->hasApiKey() && !$this->isQuotaExceeded()) {
            $raw = $this->fetchFromGoogle($lat, $lng);
            if (!empty($raw)) {
                $this->storePlaces($raw);
                $places = $this->getFromCache($lat, $lng);
            }
        }

        $requestedIds = $userId ? $this->getUserRequestedIds($userId) : [];

        foreach ($places as &$p) {
            $p['image_url']      = !empty($p['photo_reference'])
                ? '/api/place-photo?ref=' . urlencode($p['photo_reference'])
                : (self::FALLBACK_IMAGES[$p['type']] ?? self::FALLBACK_IMAGES['other']);
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

    // ── Prefetch / seeding ───────────────────────────────────────────────────

    /**
     * POST /admin/prefetch-tamilnadu?admin_id=X
     * Streams a plain-text progress log as it seeds each city.
     */
    public function prefetchTamilnadu(): void
    {
        $adminId = (int)($_GET['admin_id'] ?? 0);
        if (!$this->isAdmin($adminId)) {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden']);
            return;
        }

        $cities = [
            ['Chennai',13.0827,80.2707],['Coimbatore',11.0168,76.9558],['Madurai',9.9252,78.1198],
            ['Trichy',10.7905,78.7047],['Salem',11.6643,78.1460],['Tirunelveli',8.7139,77.7567],
            ['Vellore',12.9165,79.1325],['Erode',11.3410,77.7172],['Tiruppur',11.1085,77.3411],
            ['Thoothukudi',8.7642,78.1348],['Nagercoil',8.1833,77.4119],['Hosur',12.7409,77.8253],
            ['Kancheepuram',12.8394,79.7000],['Thanjavur',10.7870,79.1378],['Dindigul',10.3673,77.9803],
            ['Cuddalore',11.7480,79.7714],['Kumbakonam',10.9602,79.3845],['Namakkal',11.2196,78.1671],
            ['Karur',10.9601,78.0766],['Pudukkottai',10.3797,78.8201],['Villupuram',11.9401,79.4861],
            ['Krishnagiri',12.5186,78.2137],['Dharmapuri',12.1281,78.1582],['Tiruvallur',13.1437,79.9093],
            ['Chengalpattu',12.6922,79.9759],['Ranipet',12.9283,79.3328],['Tiruvannamalai',12.2253,79.0747],
            ['Tirupattur',12.4960,78.5730],['Kallakurichi',11.7354,78.9602],['Ariyalur',11.1390,79.0771],
            ['Perambalur',11.2330,78.8804],['Mayiladuthurai',11.1033,79.6533],['Nagapattinam',10.7672,79.8449],
            ['Tiruvarur',10.7726,79.6356],['Sivaganga',9.8438,78.4828],['Ramanathapuram',9.3639,78.8395],
            ['Virudhunagar',9.5872,77.9622],['Tenkasi',8.9594,77.3153],['Theni',10.0104,77.4770],
            ['Ooty',11.4102,76.6950],['Kodaikanal',10.2381,77.4892],['Pollachi',10.6554,77.0070],
            ['Palani',10.4476,77.5230],['Gobichettipalayam',11.4547,77.3572],['Bhavani',11.4451,77.6831],
            ['Mettur',11.7925,77.8011],['Sathyamangalam',11.5011,77.2340],['Sivakasi',9.4533,77.7997],
            ['Rajapalayam',9.4880,77.5527],['Ambur',12.7933,78.7185],['Gudiyatham',12.9483,78.8742],
            ['Chidambaram',11.3995,79.6913],['Rasipuram',11.4612,78.1767],['Yercaud',11.7720,78.2092],
            ['Kanyakumari',8.0883,77.5385],['Rameswaram',9.2876,79.3129],['Tiruchendur',8.4973,78.1218],
            ['Velankanni',10.6874,79.8537],['Mahabalipuram',12.6269,80.1927],['Karaikudi',10.0757,78.7734],
            ['Coonoor',11.3530,76.7959],['Mettupalayam',11.2964,76.9431],['Valparai',10.3269,76.9550],
            ['Kovilpatti',9.1706,77.8680],['Aruppukkottai',9.5091,78.0972],['Srivilliputhur',9.5117,77.6369],
            ['Sankarankovil',9.1701,77.5536],['Sattur',9.3479,77.9098],['Paramakudi',9.5197,78.5912],
            ['Periyakulam',10.1148,77.5540],['Bodinayakanur',10.0108,77.3530],['Udumalpet',10.5852,77.2486],
            ['Kangeyam',11.0061,77.5612],['Attur',11.5969,78.5992],['Arakkonam',13.0786,79.6682],
            ['Vaniyambadi',12.6840,78.6230],['Jolarpettai',12.5600,78.5767],['Harur',12.0516,78.4794],
            ['Bargur',12.1992,78.2339],['Arani',12.6701,79.2814],['Cheyyar',12.6543,79.5460],
            ['Gingee',12.2531,79.4167],['Tindivanam',12.2432,79.6569],['Ulundurpet',11.6725,79.3227],
        ];

        header('Content-Type: text/plain; charset=utf-8');
        header('X-Accel-Buffering: no'); // disable nginx buffering so lines stream live
        ob_implicit_flush(true);
        @ob_end_flush();

        $total = 0; $skipped = 0;
        echo "KoCourt — Tamil Nadu prefetch (" . count($cities) . " cities)\n";
        echo str_repeat('-', 50) . "\n";

        foreach ($cities as [$name, $lat, $lng]) {
            $count = $this->prefetchCity((float)$lat, (float)$lng);
            if ($count === 0) {
                echo "  SKIP  $name (cached or quota exceeded)\n";
                $skipped++;
            } else {
                echo "  OK    $name → $count places\n";
                $total += $count;
            }
            flush();
            sleep(1);
        }

        echo str_repeat('-', 50) . "\n";
        echo "Done. $total new places stored, $skipped skipped.\n";
    }

    /**
     * Pre-seed the cache for a specific lat/lng (used by CLI scripts).
     * Returns the number of places stored (0 if quota exceeded or no API key).
     */
    public function prefetchCity(float $lat, float $lng): int
    {
        if (!$this->hasApiKey() || $this->isQuotaExceeded()) return 0;

        // Skip if already freshly cached (avoid wasting quota)
        $existing = $this->getFromCache($lat, $lng);
        if (count($existing) > 0) return count($existing);

        $raw = $this->fetchFromGoogle($lat, $lng);
        if (!empty($raw)) {
            $this->storePlaces($raw);
        }
        return count($raw);
    }

    // ── Google Places API (New) ───────────────────────────────────────────────

    private function hasApiKey(): bool
    {
        return !empty($this->apiKey) && $this->apiKey !== 'your_google_places_api_key';
    }

    // Added primaryType + userRatingCount to detect quality venues & filter fake listings
    private const FIELD_MASK = 'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.primaryType,places.internationalPhoneNumber,places.websiteUri,places.rating,places.userRatingCount,places.photos';

    /**
     * Fetch sports venues near a location — optimised for Indian cities.
     *
     * Strategy (5 quota calls per fresh location):
     *  1. Nearby Search  — formally-typed venues (gym, badminton_court, cricket_ground…)
     *  2. Text Search × 4 — ONE query per sport so Google's AI doesn't dilute relevance.
     *
     * Why single-sport queries beat mixed keyword strings for India:
     *  Most turf grounds, box-cricket nets, badminton halls are stored in Google as plain
     *  "establishment" with no formal type. Text Search finds them by name/description.
     *  Mixed queries (e.g. "turf football futsal cricket badminton") cause Google to pick
     *  only the dominant signal and miss the rest.
     */
    private function fetchFromGoogle(float $lat, float $lng): array
    {
        $seen = [];
        $out  = [];

        // ── 1. Nearby Search — officially-typed sports venues ─────────────────
        // Uses Google Place Types (Table A). Returns formal gyms, courts, stadiums.
        // squash_court added — official type, commonly available in Indian clubs.
        if (!$this->isQuotaExceeded()) {
            $allTypes = [
                'gym', 'fitness_center',
                'badminton_court', 'tennis_court', 'basketball_court',
                'volleyball_court', 'squash_court',
                'cricket_ground', 'athletic_field', 'stadium',
                'sports_complex', 'sports_club', 'recreation_center',
                'swimming_pool', 'dance_studio', 'yoga_studio',
                'martial_arts_school', 'golf_course', 'bowling_alley',
            ];
            $this->runNearbySearch($lat, $lng, $allTypes, $seen, $out);
        }

        // ── 2. Text Search — focused single-sport queries ────────────────────
        //
        // Indian-specific terms explained:
        //   turf        — synthetic grass football ground (universal term across India)
        //   box cricket — enclosed cricket net arenas, hugely popular in Tamil Nadu/AP/KA
        //   shuttle     — common South Indian shorthand for badminton
        //   futsal      — indoor football, growing in Tamil Nadu/Kerala metros
        //   sports hub  — common multi-sport venue brand name
        //   academy     — used by almost every coaching centre in India
        $textQueries = [
            // Football / Turf — most common unlisted venue type in India
            'turf futsal football ground sports arena',

            // Badminton — largest indoor sport by venue count
            'badminton court shuttle indoor academy',

            // Cricket — box cricket nets & grounds
            'box cricket ground nets coaching academy',

            // Fitness, Yoga, Swimming — catches small unlisted centres
            'gym fitness centre yoga swimming sports academy hub',
        ];

        foreach ($textQueries as $query) {
            if ($this->isQuotaExceeded()) break;
            $this->runTextSearch($lat, $lng, $query, $seen, $out);
        }

        usort($out, fn($a, $b) => $a['_dist'] <=> $b['_dist']);
        return array_map(function ($p) { unset($p['_dist']); return $p; }, $out);
    }

    /** Nearby Search (New) — max 20 results, sorted by distance */
    private function runNearbySearch(
        float $lat, float $lng, array $types, array &$seen, array &$out
    ): void {
        $body = json_encode([
            'includedTypes'       => $types,
            'locationRestriction' => [
                // 15 km radius — more appropriate for Tier-2/3 Indian cities
                'circle' => ['center' => ['latitude' => $lat, 'longitude' => $lng], 'radius' => 15000.0],
            ],
            'maxResultCount' => 20,
            'rankPreference' => 'DISTANCE',
        ]);

        $resp = $this->postPlaces('https://places.googleapis.com/v1/places:searchNearby', $body);
        $this->incrementQuota();
        $this->parsePlacesResponse($resp, $lat, $lng, $seen, $out);
    }

    /**
     * Text Search (New) — single focused query, no pagination.
     * Uses locationBias (soft) so venues just outside 15 km still surface.
     * rankPreference DISTANCE ensures nearest venues appear first.
     */
    private function runTextSearch(
        float $lat, float $lng, string $query, array &$seen, array &$out
    ): void {
        $payload = [
            'textQuery'      => $query,
            'locationBias'   => [
                'circle' => ['center' => ['latitude' => $lat, 'longitude' => $lng], 'radius' => 15000.0],
            ],
            'pageSize'       => 20,
            'rankPreference' => 'DISTANCE',
        ];

        $resp = $this->postPlaces('https://places.googleapis.com/v1/places:searchText', json_encode($payload));
        $this->incrementQuota();
        $this->parsePlacesResponse($resp, $lat, $lng, $seen, $out);
    }

    /** Shared cURL POST helper for Places API (New) */
    private function postPlaces(string $endpoint, string $body): string
    {
        $ch = curl_init($endpoint);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $body,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_USERAGENT      => 'KoCourt/1.0',
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'X-Goog-Api-Key: '  . $this->apiKey,
                'X-Goog-FieldMask: ' . self::FIELD_MASK,
            ],
        ]);
        $resp     = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        return ($httpCode === 200 && $resp) ? $resp : '';
    }

    /** Parse a Places API response, deduplicate by google_place_id, append to $out */
    private function parsePlacesResponse(
        string $resp, float $lat, float $lng, array &$seen, array &$out
    ): void {
        if (!$resp) return;
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
                'photo_reference' => $r['photos'][0]['name'] ?? null,
                '_dist'           => $this->haversine($lat, $lng, $elLat, $elLng),
            ];
        }
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

    /**
     * Infer the app's sport type from a venue name + Google place types.
     * Order matters — check most-specific first before falling through to gym/other.
     * Indian-specific terms are marked with (IN).
     */
    private function inferType(string $name, array $types = []): string
    {
        $n = strtolower($name . ' ' . implode(' ', $types));

        // Badminton — check before "shuttle" which can be ambiguous
        if (strpos($n, 'badminton')     !== false) return 'shuttle';
        if (strpos($n, 'shuttle')       !== false) return 'shuttle'; // (IN) South Indian term
        if (strpos($n, 'badminton_court')!== false) return 'shuttle';

        // Cricket — box cricket must match before generic "cricket"
        if (strpos($n, 'box cricket')   !== false) return 'cricket'; // (IN) enclosed cricket nets
        if (strpos($n, 'cricket')       !== false) return 'cricket';
        if (strpos($n, 'cricket_ground')!== false) return 'cricket';

        // Tennis
        if (strpos($n, 'tennis')        !== false) return 'tennis';
        if (strpos($n, 'squash')        !== false) return 'tennis'; // group squash with tennis

        // Swimming
        if (strpos($n, 'swim')          !== false) return 'swimming';
        if (strpos($n, 'pool')          !== false) return 'swimming';
        if (strpos($n, 'aqua')          !== false) return 'swimming';
        if (strpos($n, 'swimming_pool') !== false) return 'swimming';

        // Basketball / Volleyball
        if (strpos($n, 'basket')        !== false) return 'basket';
        if (strpos($n, 'basketball_court')!== false) return 'basket';
        if (strpos($n, 'volleyball')    !== false) return 'basket'; // group with basket

        // Football / Turf — check turf BEFORE generic football to catch "XYZ Turf" names
        if (strpos($n, 'turf')          !== false) return 'turf'; // (IN) most common name
        if (strpos($n, 'futsal')        !== false) return 'turf'; // (IN) indoor football
        if (strpos($n, 'football')      !== false) return 'turf';
        if (strpos($n, 'soccer')        !== false) return 'turf';
        if (strpos($n, 'athletic_field')!== false) return 'turf';

        // Martial arts / Combat sports
        if (strpos($n, 'karate')        !== false) return 'martial';
        if (strpos($n, 'taekwondo')     !== false) return 'martial';
        if (strpos($n, 'judo')          !== false) return 'martial';
        if (strpos($n, 'mma')           !== false) return 'martial';
        if (strpos($n, 'boxing')        !== false) return 'martial';
        if (strpos($n, 'martial')       !== false) return 'martial';
        if (strpos($n, 'martial_arts')  !== false) return 'martial';
        if (strpos($n, 'kabaddi')       !== false) return 'martial'; // (IN)
        if (strpos($n, 'kho kho')       !== false) return 'martial'; // (IN)
        if (strpos($n, 'wrestling')     !== false) return 'martial';

        // Yoga / Meditation
        if (strpos($n, 'yoga')          !== false) return 'yoga';
        if (strpos($n, 'meditation')    !== false) return 'yoga';
        if (strpos($n, 'pilates')       !== false) return 'yoga';
        if (strpos($n, 'zumba')         !== false) return 'yoga';

        // Dance
        if (strpos($n, 'dance')         !== false) return 'dance';
        if (strpos($n, 'dance_studio')  !== false) return 'dance';

        // Golf
        if (strpos($n, 'golf')          !== false) return 'golf';

        // Bowling
        if (strpos($n, 'bowling')       !== false) return 'bowling';

        // Gym / Fitness — last before 'other' so sports academies with gym don't fall here
        if (strpos($n, 'gym')           !== false) return 'gym';
        if (strpos($n, 'fitness')       !== false) return 'gym';
        if (strpos($n, 'crossfit')      !== false) return 'gym';
        if (strpos($n, 'fitness_center')!== false) return 'gym';
        if (strpos($n, 'workout')       !== false) return 'gym';

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
               AND cached_at > DATE_SUB(NOW(), INTERVAL 60 DAY)
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
                name            = VALUES(name),
                address         = VALUES(address),
                phone           = COALESCE(VALUES(phone), phone),
                website         = COALESCE(VALUES(website), website),
                rating          = COALESCE(VALUES(rating), rating),
                photo_reference = COALESCE(VALUES(photo_reference), photo_reference),
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
