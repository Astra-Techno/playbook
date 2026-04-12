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

        $court = new Court();
        $stmt  = $court->read($location, $type, $owner_id, $lat, $lng);

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

            if ($court->create()) {
                http_response_code(201);
                echo json_encode(["message" => "Court was created."]);
            } else {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create court."]);
            }
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Data is incomplete."]);
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
            evening_peak_start=?, evening_peak_end=?, peak_members_only=?
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
            $id, $owner_id
        ]);
        http_response_code(200);
        echo json_encode(['message' => 'Court updated.']);
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
