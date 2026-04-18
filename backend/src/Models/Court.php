<?php

require_once __DIR__ . '/../../config/database.php';

class Court {
    private $conn;
    private $table_name = "courts";

    public $id;
    public $owner_id;
    public $name;
    public $type;
    public $description;
    public $location;
    public $hourly_rate;
    public $image_url;
    public $lat;
    public $lng;
    public $open_time;
    public $close_time;
    public $morning_peak_start;
    public $morning_peak_end;
    public $evening_peak_start;
    public $evening_peak_end;
    public $peak_members_only;
    public $amenities;
    public $created_at;

    public function __construct() {
        $this->conn = Database::getConnection();
    }

    /**
     * Read courts with optional filters.
     * - If $lat + $lng provided (and no $owner_id): GPS Haversine search within $radius km.
     * - Otherwise: text LIKE search on location, optional type/owner filters.
     * - If $for_admin: include courts with pending/rejected claims (public API hides pending).
     */
    public function read($location = null, $type = null, $owner_id = null,
                         $lat = null, $lng = null, $radius = 25, $for_admin = false) {

        // GPS proximity search (player discovering courts)
        if ($lat !== null && $lng !== null && !$owner_id) {
            $conditions = ['c.lat IS NOT NULL', 'c.lng IS NOT NULL'];
            if (!$for_admin) {
                $conditions[] = "(c.claim_status IS NULL OR c.claim_status = 'approved')";
            }
            if ($type && $type !== 'All') $conditions[] = "c.type = ?";

            $where = implode(" AND ", $conditions);

            $query = "SELECT c.*,
                AVG(r.rating) AS avg_rating,
                COUNT(r.id)   AS review_count,
                (6371 * acos(LEAST(1.0,
                    cos(radians(?)) * cos(radians(c.lat)) * cos(radians(c.lng) - radians(?)) +
                    sin(radians(?)) * sin(radians(c.lat))
                ))) AS distance
                FROM {$this->table_name} c
                LEFT JOIN reviews r ON r.court_id = c.id
                WHERE {$where}
                GROUP BY c.id
                HAVING distance < ?
                ORDER BY distance ASC";

            $stmt = $this->conn->prepare($query);

            // Positional binding: lat, lng, lat (again), [type,] radius
            $params = [(float)$lat, (float)$lng, (float)$lat];
            if ($type && $type !== 'All') $params[] = $type;
            $params[] = (float)$radius;

            $stmt->execute($params);
            return $stmt;
        }

        // Text / owner filter search
        $conditions = [];
        // Only exclude pending courts for public searches (not owner's own dashboard or admin list)
        if (!$owner_id && !$for_admin) {
            $conditions[] = "(c.claim_status IS NULL OR c.claim_status = 'approved')";
        }
        if ($location && $location !== 'All') $conditions[] = "c.location LIKE ?";
        if ($type     && $type     !== 'All') $conditions[] = "c.type = ?";
        if ($owner_id)                        $conditions[] = "c.owner_id = ?";

        $query = "SELECT c.*, AVG(r.rating) AS avg_rating, COUNT(r.id) AS review_count
                  FROM {$this->table_name} c
                  LEFT JOIN reviews r ON r.court_id = c.id";
        if ($conditions) $query .= " WHERE " . implode(" AND ", $conditions);
        $query .= " GROUP BY c.id ORDER BY c.created_at DESC";

        $stmt = $this->conn->prepare($query);

        $params = [];
        if ($location && $location !== 'All') $params[] = "%{$location}%";
        if ($type     && $type     !== 'All') $params[] = $type;
        if ($owner_id)                        $params[] = $owner_id;

        $stmt->execute($params);
        return $stmt;
    }

    public function create() {
        $query = "INSERT INTO {$this->table_name}
                  SET owner_id=:owner_id, name=:name, type=:type, description=:description,
                      location=:location, hourly_rate=:hourly_rate, image_url=:image_url,
                      lat=:lat, lng=:lng,
                      open_time=:open_time, close_time=:close_time,
                      morning_peak_start=:mps, morning_peak_end=:mpe,
                      evening_peak_start=:eps, evening_peak_end=:epe,
                      peak_members_only=:pmo, amenities=:amenities";

        $stmt = $this->conn->prepare($query);

        $this->name        = htmlspecialchars(strip_tags($this->name));
        $this->type        = htmlspecialchars(strip_tags($this->type));
        $this->description = htmlspecialchars(strip_tags($this->description));
        $this->location    = htmlspecialchars(strip_tags($this->location));
        $this->hourly_rate = htmlspecialchars(strip_tags($this->hourly_rate));
        $this->image_url   = htmlspecialchars(strip_tags($this->image_url));
        $latVal = $this->lat  ? (float)$this->lat  : null;
        $lngVal = $this->lng  ? (float)$this->lng  : null;

        $ot  = $this->open_time          ?? '06:00:00';
        $ct  = $this->close_time         ?? '22:00:00';
        $mps = $this->morning_peak_start ?? '05:00:00';
        $mpe = $this->morning_peak_end   ?? '09:00:00';
        $eps = $this->evening_peak_start ?? '17:00:00';
        $epe = $this->evening_peak_end   ?? '21:00:00';
        $pmo = $this->peak_members_only  ? 1 : 0;

        $stmt->bindParam(":owner_id",    $this->owner_id);
        $stmt->bindParam(":name",        $this->name);
        $stmt->bindParam(":type",        $this->type);
        $stmt->bindParam(":description", $this->description);
        $stmt->bindParam(":location",    $this->location);
        $stmt->bindParam(":hourly_rate", $this->hourly_rate);
        $stmt->bindParam(":image_url",   $this->image_url);
        $stmt->bindParam(":lat",         $latVal);
        $stmt->bindParam(":lng",         $lngVal);
        $stmt->bindParam(":open_time",   $ot);
        $stmt->bindParam(":close_time",  $ct);
        $stmt->bindParam(":mps",         $mps);
        $stmt->bindParam(":mpe",         $mpe);
        $stmt->bindParam(":eps",         $eps);
        $stmt->bindParam(":epe",         $epe);
        $stmt->bindParam(":pmo",         $pmo);
        $amenitiesVal = $this->amenities ?? null;
        $stmt->bindParam(":amenities",   $amenitiesVal);

        return $stmt->execute();
    }
}
