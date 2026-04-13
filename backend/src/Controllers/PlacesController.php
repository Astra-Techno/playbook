<?php

class PlacesController
{
    private PDO    $db;
    private string $googleApiKey;
    private string $mmiClientId;
    private string $mmiClientSecret;

    // Fallback Unsplash images per sport type
    private const FALLBACK_IMAGES = [
        'shuttle'  => 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=600&q=80',
        'turf'     => 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=600&q=80',
        'gym'      => 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
        'cricket'  => 'https://images.unsplash.com/photo-1540747913346-19212a4b8277?w=600&q=80',
        'tennis'   => 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
        'basket'   => 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600&q=80',
        'swimming' => 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?w=600&q=80',
        'boxing'   => 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=600&q=80',
        'squash'   => 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=600&q=80',
        'other'    => 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80',
    ];

    public function __construct()
    {
        $this->db              = Database::getConnection();
        $this->googleApiKey    = getenv('GOOGLE_PLACES_API_KEY')    ?: '';
        $this->mmiClientId     = getenv('MAPMYINDIA_CLIENT_ID')     ?: '';
        $this->mmiClientSecret = getenv('MAPMYINDIA_CLIENT_SECRET') ?: '';
        $this->ensureTables();
    }

    // ── GET /nearby-places?lat=&lng=&user_id= ────────────────────────────────

    public function nearby(): void
    {
        $lat    = isset($_GET['lat'])     ? (float)$_GET['lat']     : null;
        $lng    = isset($_GET['lng'])     ? (float)$_GET['lng']     : null;
        $userId = isset($_GET['user_id']) ? (int)$_GET['user_id']   : null;

        if ($lat === null || $lng === null) {
            http_response_code(400);
            echo json_encode(['error' => 'lat and lng are required']);
            return;
        }

        // Serve from cache first (within ~2 km, last 24 h)
        $places = $this->getFromCache($lat, $lng);

        if (empty($places)) {
            // Priority: Google Places → MapmyIndia → Overpass → Demo
            $raw = $this->hasGoogle() ? $this->fetchFromGoogle($lat, $lng) : [];
            if (empty($raw)) {
                $raw = $this->hasMmi() ? $this->fetchFromMapmyIndia($lat, $lng) : [];
            }
            if (empty($raw)) {
                $raw = $this->fetchFromOverpass($lat, $lng);
            }
            if (empty($raw)) {
                $raw = $this->getDemoPlaces($lat, $lng);
            }
            $this->storePlaces($raw);
            $places = $this->getFromCache($lat, $lng);
        }

        // Attach image + user-request flag
        $requestedIds = $userId ? $this->getUserRequestedIds($userId) : [];

        foreach ($places as &$p) {
            $p['image_url']      = self::FALLBACK_IMAGES[$p['type']] ?? self::FALLBACK_IMAGES['other'];
            $p['user_requested'] = in_array((int)$p['id'], $requestedIds, true);
            unset($p['photo_reference']); // not used with OSM
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

        $countRow = $this->db->prepare("SELECT request_count FROM places WHERE id = ?");
        $countRow->execute([$placeId]);
        $count = (int)$countRow->fetchColumn();

        if ($inserted && $count >= 5 && $place['status'] === 'unregistered') {
            $this->flagForOutreach($placeId);
        }

        echo json_encode([
            'success'       => true,
            'requested'     => true,
            'request_count' => $count,
        ]);
    }

    // ── Admin: GET /admin/demand?admin_id= ───────────────────────────────────

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

    // ── Google Places API ────────────────────────────────────────────────────

    private function hasGoogle(): bool
    {
        return !empty($this->googleApiKey) && $this->googleApiKey !== 'your_google_places_api_key';
    }

    private function fetchFromGoogle(float $lat, float $lng): array
    {
        // Use the newer Places API (v1) — supports fieldMask for cost control
        // Basic fields (displayName, location, formattedAddress, types) are FREE
        // We only request fields in the Basic tier to avoid charges
        $url = 'https://places.googleapis.com/v1/places:searchNearby';

        $body = json_encode([
            'includedTypes'    => [
                'sports_complex', 'sports_club', 'stadium', 'gym', 'fitness_center',
                'swimming_pool', 'golf_course', 'bowling_alley',
            ],
            'locationRestriction' => [
                'circle' => [
                    'center' => ['latitude' => $lat, 'longitude' => $lng],
                    'radius' => 10000.0,
                ],
            ],
            'maxResultCount' => 20,
            'rankPreference'  => 'DISTANCE',
        ]);

        if (!function_exists('curl_init')) return [];
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $body,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_USERAGENT      => 'KoCourt/1.0',
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'X-Goog-Api-Key: ' . $this->googleApiKey,
                // Only request Basic tier fields — these are FREE (no charge per field)
                'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,places.types,places.internationalPhoneNumber,places.websiteUri,places.rating',
            ],
        ]);
        $resp     = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200 || !$resp) return [];

        $data = json_decode($resp, true);
        if (empty($data['places'])) return [];

        $out  = [];
        $seen = [];

        foreach ($data['places'] as $r) {
            $placeId = $r['id'] ?? null;
            $name    = $r['displayName']['text'] ?? null;
            if (!$placeId || !$name || isset($seen[$placeId])) continue;
            $seen[$placeId] = true;

            $elLat = $r['location']['latitude']  ?? null;
            $elLng = $r['location']['longitude'] ?? null;
            if ($elLat === null || $elLng === null) continue;

            $out[] = [
                'google_place_id' => $placeId,
                'name'            => $name,
                'type'            => $this->inferTypeFromName($name, implode(' ', $r['types'] ?? [])),
                'address'         => $r['formattedAddress'] ?? '',
                'lat'             => (float)$elLat,
                'lng'             => (float)$elLng,
                'phone'           => $r['internationalPhoneNumber'] ?? null,
                'website'         => $r['websiteUri'] ?? null,
                'rating'          => isset($r['rating']) ? (float)$r['rating'] : null,
                'photo_reference' => null,
                '_dist'           => $this->haversine($lat, $lng, (float)$elLat, (float)$elLng),
            ];
        }

        // Google caps at 20 per call — make a second pass with different types
        $moreTypes = [
            'athletic_field', 'basketball_court', 'cricket_ground',
            'tennis_court', 'volleyball_court', 'badminton_court',
        ];
        $body2 = json_encode([
            'includedTypes'       => $moreTypes,
            'locationRestriction' => [
                'circle' => [
                    'center' => ['latitude' => $lat, 'longitude' => $lng],
                    'radius' => 10000.0,
                ],
            ],
            'maxResultCount' => 20,
            'rankPreference'  => 'DISTANCE',
        ]);
        $ch2 = curl_init($url);
        curl_setopt_array($ch2, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $body2,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_USERAGENT      => 'KoCourt/1.0',
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'X-Goog-Api-Key: ' . $this->googleApiKey,
                'X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,places.types,places.internationalPhoneNumber,places.websiteUri,places.rating',
            ],
        ]);
        $resp2     = curl_exec($ch2);
        $httpCode2 = curl_getinfo($ch2, CURLINFO_HTTP_CODE);
        curl_close($ch2);

        if ($httpCode2 === 200 && $resp2) {
            $data2 = json_decode($resp2, true);
            foreach ($data2['places'] ?? [] as $r) {
                $placeId = $r['id'] ?? null;
                $name    = $r['displayName']['text'] ?? null;
                if (!$placeId || !$name || isset($seen[$placeId])) continue;
                $seen[$placeId] = true;

                $elLat = $r['location']['latitude']  ?? null;
                $elLng = $r['location']['longitude'] ?? null;
                if ($elLat === null || $elLng === null) continue;

                $out[] = [
                    'google_place_id' => $placeId,
                    'name'            => $name,
                    'type'            => $this->inferTypeFromName($name, implode(' ', $r['types'] ?? [])),
                    'address'         => $r['formattedAddress'] ?? '',
                    'lat'             => (float)$elLat,
                    'lng'             => (float)$elLng,
                    'phone'           => $r['internationalPhoneNumber'] ?? null,
                    'website'         => $r['websiteUri'] ?? null,
                    'rating'          => isset($r['rating']) ? (float)$r['rating'] : null,
                    'photo_reference' => null,
                    '_dist'           => $this->haversine($lat, $lng, (float)$elLat, (float)$elLng),
                ];
            }
        }

        usort($out, fn($a, $b) => $a['_dist'] <=> $b['_dist']);

        return array_map(function ($p) {
            unset($p['_dist']);
            return $p;
        }, $out);
    }

    // ── MapmyIndia Places API ────────────────────────────────────────────────

    private function hasMmi(): bool
    {
        return !empty($this->mmiClientId) && !empty($this->mmiClientSecret);
    }

    private function getMmiToken(): ?string
    {
        // Cache token in a temp file (valid ~6 hours, we refresh every 5)
        $cacheFile = sys_get_temp_dir() . '/mmi_token.json';
        if (file_exists($cacheFile)) {
            $cached = json_decode(file_get_contents($cacheFile), true);
            if ($cached && isset($cached['token'], $cached['expires_at']) && time() < $cached['expires_at']) {
                return $cached['token'];
            }
        }

        $resp = $this->curlPost(
            'https://outpost.mapmyindia.com/api/security/oauth/token',
            http_build_query([
                'grant_type'    => 'client_credentials',
                'client_id'     => $this->mmiClientId,
                'client_secret' => $this->mmiClientSecret,
            ]),
            10
        );

        if (!$resp) return null;
        $data = json_decode($resp, true);
        if (empty($data['access_token'])) return null;

        file_put_contents($cacheFile, json_encode([
            'token'      => $data['access_token'],
            'expires_at' => time() + 18000, // 5 hours
        ]));

        return $data['access_token'];
    }

    private function fetchFromMapmyIndia(float $lat, float $lng): array
    {
        $token = $this->getMmiToken();
        if (!$token) return [];
        if (!function_exists('curl_init')) return [];

        // Split into keyword batches — MMI returns ~10 per call, so multiple calls = more results
        $keywordBatches = [
            'Badminton Court;Shuttle Court;Badminton Academy;Tennis Court;Squash Court',
            'Cricket Ground;Cricket Stadium;Cricket Club;Cricket Academy',
            'Football Ground;Turf;Futsal Court;Football Club;Soccer Ground',
            'Sports Complex;Sports Club;Sports Academy;Sports Centre;Sports Arena',
            'Gymnasium;Gym;Fitness Centre;Crossfit;Yoga Centre',
            'Swimming Pool;Aquatic Centre;Swim Club',
            'Basketball Court;Volleyball Court;Boxing Club;Martial Arts',
        ];

        $out  = [];
        $seen = [];

        foreach ($keywordBatches as $keywords) {
            // Fetch page 1 and page 2 for each batch
            for ($page = 1; $page <= 2; $page++) {
                $url = 'https://atlas.mapmyindia.com/api/places/nearby/json'
                     . '?keywords='    . urlencode($keywords)
                     . '&refLocation=' . $lat . ',' . $lng
                     . '&radius=10000'
                     . '&page='        . $page;

                $ch = curl_init($url);
                curl_setopt_array($ch, [
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_TIMEOUT        => 10,
                    CURLOPT_SSL_VERIFYPEER => true,
                    CURLOPT_USERAGENT      => 'KoCourt/1.0',
                    CURLOPT_HTTPHEADER     => ['Authorization: Bearer ' . $token],
                ]);
                $resp     = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                curl_close($ch);

                if ($httpCode !== 200 || !$resp) continue;

                $data = json_decode($resp, true);
                if (empty($data['suggestedLocations'])) break; // no more pages

                foreach ($data['suggestedLocations'] as $r) {
                    $name = trim($r['placeName'] ?? '');
                    $eloc = $r['eLoc'] ?? null;
                    if (!$name || !$eloc || isset($seen[$eloc])) continue;
                    $seen[$eloc] = true;

                    $elLat = isset($r['latitude'])  ? (float)$r['latitude']  : null;
                    $elLng = isset($r['longitude']) ? (float)$r['longitude'] : null;
                    if ($elLat === null || $elLng === null) continue;

                    $address = trim($r['placeAddress'] ?? '');
                    if (!$address) {
                        $dist    = isset($r['distance']) ? round($r['distance'] / 1000, 1) : null;
                        $address = $dist ? $dist . ' km away' : '';
                    }

                    $out[] = [
                        'google_place_id' => 'mmi_' . $eloc,
                        'name'            => $name,
                        'type'            => $this->inferTypeFromName($name, $r['type'] ?? ''),
                        'address'         => $address,
                        'lat'             => $elLat,
                        'lng'             => $elLng,
                        'phone'           => null,
                        'website'         => null,
                        'rating'          => null,
                        'photo_reference' => null,
                        '_dist'           => isset($r['distance']) ? (float)$r['distance'] / 1000 : $this->haversine($lat, $lng, $elLat, $elLng),
                    ];
                }
            }
        }

        usort($out, fn($a, $b) => $a['_dist'] <=> $b['_dist']);

        return array_map(function ($p) {
            unset($p['_dist']);
            return $p;
        }, $out);
    }

    private function inferTypeFromName(string $name, string $category = ''): string
    {
        $n = strtolower($name . ' ' . $category);
        if (strpos($n, 'badminton') !== false || strpos($n, 'shuttle') !== false) return 'shuttle';
        if (strpos($n, 'cricket')   !== false) return 'cricket';
        if (strpos($n, 'tennis')    !== false) return 'tennis';
        if (strpos($n, 'swim')      !== false || strpos($n, 'pool') !== false || strpos($n, 'aqua') !== false) return 'swimming';
        if (strpos($n, 'basket')    !== false) return 'basket';
        if (strpos($n, 'football')  !== false || strpos($n, 'turf') !== false || strpos($n, 'futsal') !== false || strpos($n, 'soccer') !== false) return 'turf';
        if (strpos($n, 'boxing')    !== false || strpos($n, 'martial') !== false || strpos($n, 'mma') !== false) return 'boxing';
        if (strpos($n, 'gym')       !== false || strpos($n, 'fitness') !== false || strpos($n, 'crossfit') !== false) return 'gym';
        return 'other';
    }

    // ── Overpass API (OpenStreetMap) ─────────────────────────────────────────

    private function fetchFromOverpass(float $lat, float $lng): array
    {
        $r = 10000; // 10 km radius — wider for smaller Indian cities

        // Two-pass query:
        // Pass 1: tag-based (precise) — sport/leisure/amenity tags
        // Pass 2: name-based regex (catches untagged Indian venues by name)
        $query = '[out:json][timeout:25];'
            . '('
            // Tag-based — nodes
            . 'node["leisure"~"sports_centre|fitness_centre|stadium|pitch|swimming_pool"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . 'node["sport"~"badminton|tennis|cricket|football|soccer|futsal|swimming|basketball|boxing|squash|volleyball|kabaddi|hockey"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . 'node["amenity"~"gym|sports_centre|swimming_pool|stadium"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            // Tag-based — ways (buildings/grounds)
            . 'way["leisure"~"sports_centre|fitness_centre|stadium|pitch|swimming_pool"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . 'way["sport"~"badminton|tennis|cricket|football|soccer|futsal|swimming|basketball|boxing|squash|volleyball|kabaddi|hockey"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . 'way["amenity"~"gym|sports_centre|swimming_pool|stadium"](around:' . $r . ',' . $lat . ',' . $lng . ');'
            // Name-based — catches untagged Indian venues (e.g. "Sivakasi Badminton Court")
            . 'node["name"~"badminton|cricket|tennis|turf|stadium|gym|fitness|swimming|basketball|boxing|squash|sports|court|arena|ground|academy|club",i](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . 'way["name"~"badminton|cricket|tennis|turf|stadium|gym|fitness|swimming|basketball|boxing|squash|sports|court|arena|ground|academy|club",i](around:' . $r . ',' . $lat . ',' . $lng . ');'
            . ');'
            . 'out center 40;';

        // Try primary mirror, fallback to secondary
        $mirrors = [
            'https://overpass-api.de/api/interpreter',
            'https://overpass.kumi.systems/api/interpreter',
        ];

        $response = false;
        foreach ($mirrors as $url) {
            $response = $this->curlPost($url, 'data=' . urlencode($query), 20);
            if ($response !== false) break;
        }

        if (!$response) return [];

        $data = json_decode($response, true);
        if (!isset($data['elements'])) return [];

        $out  = [];
        $seen = [];

        foreach ($data['elements'] as $el) {
            // Nodes have lat/lon; ways return center point
            $elLat = isset($el['lat']) ? (float)$el['lat'] : (isset($el['center']['lat']) ? (float)$el['center']['lat'] : null);
            $elLng = isset($el['lon']) ? (float)$el['lon'] : (isset($el['center']['lon']) ? (float)$el['center']['lon'] : null);
            if ($elLat === null || $elLng === null) continue;

            $tags = $el['tags'] ?? [];
            $name = isset($tags['name']) ? trim($tags['name']) : null;
            if (!$name) continue; // skip unnamed map features

            $osmId = $el['type'] . '_' . $el['id'];
            if (isset($seen[$osmId])) continue;
            $seen[$osmId] = true;

            // Build human-readable address from OSM tags
            $address = $this->buildOsmAddress($tags, $lat, $lng, $elLat, $elLng);

            $out[] = [
                'google_place_id' => $osmId,           // reuse column; stores OSM ID
                'name'            => $name,
                'type'            => $this->inferTypeFromOsm($tags),
                'address'         => $address,
                'lat'             => $elLat,
                'lng'             => $elLng,
                'phone'           => $tags['phone'] ?? $tags['contact:phone'] ?? $tags['contact:mobile'] ?? null,
                'website'         => $tags['website'] ?? $tags['contact:website'] ?? null,
                'rating'          => null,
                'photo_reference' => null,
                '_dist'           => $this->haversine($lat, $lng, $elLat, $elLng),
            ];
        }

        // Sort nearest first
        usort($out, fn($a, $b) => $a['_dist'] <=> $b['_dist']);

        return array_map(function ($p) {
            unset($p['_dist']);
            return $p;
        }, $out);
    }

    private function buildOsmAddress(array $tags, float $userLat, float $userLng, float $elLat, float $elLng): string
    {
        // Prefer full address from OSM tags
        if (!empty($tags['addr:full'])) {
            return $tags['addr:full'];
        }

        $parts = array_filter([
            $tags['addr:housenumber'] ?? null,
            $tags['addr:street']      ?? null,
            $tags['addr:suburb']      ?? ($tags['addr:neighbourhood'] ?? null),
            $tags['addr:city']        ?? ($tags['addr:town'] ?? null),
        ]);

        if (!empty($parts)) {
            return implode(', ', $parts);
        }

        // Distance fallback
        $dist = $this->haversine($userLat, $userLng, $elLat, $elLng);
        return round($dist, 1) . ' km away';
    }

    private function inferTypeFromOsm(array $tags): string
    {
        $sport   = strtolower($tags['sport']   ?? '');
        $leisure = strtolower($tags['leisure'] ?? '');
        $amenity = strtolower($tags['amenity'] ?? '');
        $name    = strtolower($tags['name']    ?? '');

        // sport tag is most precise
        if (strpos($sport, 'badminton') !== false || strpos($sport, 'shuttlecock') !== false) return 'shuttle';
        if (strpos($sport, 'tennis')    !== false) return 'tennis';
        if (strpos($sport, 'cricket')   !== false) return 'cricket';
        if (strpos($sport, 'swimming')  !== false) return 'swimming';
        if (strpos($sport, 'basketball')!== false) return 'basket';
        if (strpos($sport, 'football')  !== false || strpos($sport, 'soccer') !== false || strpos($sport, 'futsal') !== false) return 'turf';
        if (strpos($sport, 'boxing')    !== false || strpos($sport, 'martial') !== false || strpos($sport, 'kabaddi') !== false) return 'boxing';
        if (strpos($sport, 'squash')    !== false || strpos($sport, 'volleyball') !== false) return 'squash';

        // leisure / amenity tag
        if ($leisure === 'fitness_centre' || $amenity === 'gym') return 'gym';
        if ($leisure === 'swimming_pool') return 'swimming';
        if ($leisure === 'pitch') return 'turf';

        // name-based fallback
        if (strpos($name, 'badminton') !== false || strpos($name, 'shuttle') !== false) return 'shuttle';
        if (strpos($name, 'turf')      !== false || strpos($name, 'football') !== false || strpos($name, 'futsal') !== false) return 'turf';
        if (strpos($name, 'cricket')   !== false) return 'cricket';
        if (strpos($name, 'tennis')    !== false) return 'tennis';
        if (strpos($name, 'swim')      !== false || strpos($name, 'pool') !== false || strpos($name, 'aqua') !== false) return 'swimming';
        if (strpos($name, 'basket')    !== false) return 'basket';
        if (strpos($name, 'boxing')    !== false || strpos($name, 'martial') !== false || strpos($name, 'mma') !== false) return 'boxing';
        if (strpos($name, 'gym')       !== false || strpos($name, 'fitness') !== false || strpos($name, 'crossfit') !== false) return 'gym';

        return 'other';
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private function curlPost(string $url, string $body, int $timeout): ?string
    {
        if (!function_exists('curl_init')) return null;
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $body,
            CURLOPT_TIMEOUT        => $timeout,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_USERAGENT      => 'KoCourt/1.0 (sports-booking-app)',
            CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
        ]);
        $result   = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return ($httpCode === 200 && $result) ? $result : null;
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
        $delta = 0.018; // ~2 km
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
                $p['phone']   ?? null,
                $p['website'] ?? null,
                $p['rating']  ?? null,
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

    private function flagForOutreach(int $placeId): void
    {
        $this->db->prepare(
            "UPDATE places SET status = 'contacted' WHERE id = ? AND status = 'unregistered'"
        )->execute([$placeId]);
        // TODO: send WhatsApp/SMS to places.phone when 5+ requests come in
    }

    // Demo fallback when Overpass is unreachable
    private function getDemoPlaces(float $lat, float $lng): array
    {
        return [
            ['google_place_id' => 'demo_p1', 'name' => 'City Badminton Academy',    'type' => 'shuttle',  'address' => '2.1 km away', 'lat' => $lat + 0.005, 'lng' => $lng + 0.003, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
            ['google_place_id' => 'demo_p2', 'name' => 'FitZone Sports Club',       'type' => 'gym',      'address' => '1.4 km away', 'lat' => $lat - 0.004, 'lng' => $lng + 0.006, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
            ['google_place_id' => 'demo_p3', 'name' => 'Green Turf Football Arena', 'type' => 'turf',     'address' => '3.0 km away', 'lat' => $lat + 0.008, 'lng' => $lng - 0.005, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
            ['google_place_id' => 'demo_p4', 'name' => 'Victory Cricket Ground',    'type' => 'cricket',  'address' => '2.7 km away', 'lat' => $lat - 0.007, 'lng' => $lng - 0.004, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
            ['google_place_id' => 'demo_p5', 'name' => 'AquaFit Swimming Centre',   'type' => 'swimming', 'address' => '1.8 km away', 'lat' => $lat + 0.002, 'lng' => $lng + 0.009, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
            ['google_place_id' => 'demo_p6', 'name' => 'Smash Tennis Club',         'type' => 'tennis',   'address' => '3.5 km away', 'lat' => $lat - 0.010, 'lng' => $lng + 0.002, 'phone' => null, 'website' => null, 'rating' => null, 'photo_reference' => null],
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
