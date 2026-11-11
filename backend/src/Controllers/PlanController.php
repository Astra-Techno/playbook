<?php

require_once __DIR__ . '/../Models/Plan.php';

class PlanController {

    /** Mutating a plan is permitted only for the venue owner (or an admin). */
    private function authorizeCourt(int $courtId): bool {
        $authUser = Auth::requireOwner();
        if ($authUser['role'] === 'admin') return true;

        $db = Database::getConnection();
        $stmt = $db->prepare('SELECT id FROM courts WHERE id = ? AND owner_id = ?');
        $stmt->execute([$courtId, (int)$authUser['id']]);
        if ($stmt->fetch()) return true;

        http_response_code(403);
        echo json_encode(['message' => 'Forbidden']);
        return false;
    }
    
    // GET /api/plans?court_id=X[&sub_court_id=Y]
    public function index() {
        $court_id     = $_GET['court_id'] ?? null;
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        $manage = isset($_GET['manage']) && $_GET['manage'] !== '0' && $_GET['manage'] !== '';
        if ($manage) {
            $user = Auth::require();
            $own = Database::getConnection()->prepare('SELECT owner_id FROM courts WHERE id = ?');
            $own->execute([(int)$court_id]);
            $ownerId = $own->fetchColumn();
            if ($ownerId === false || ((int)$ownerId !== (int)$user['id'] && ($user['role'] ?? '') !== 'admin')) {
                http_response_code(403);
                echo json_encode(['message' => 'Forbidden']);
                return;
            }
        }

        $plan = new Plan();
        $stmt = $plan->readByCourt($court_id, $sub_court_id, !$manage);

        $plans_arr = ["records" => []];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $plans_arr["records"][] = [
                "id"            => $row["id"],
                "court_id"      => $row["court_id"],
                "sub_court_id"  => $row["sub_court_id"] ?? null,
                "name"          => $row["name"],
                "description"   => $row["description"],
                "benefits"      => $row["benefits"] ?? '',
                "is_active"     => isset($row["is_active"]) ? (int)$row["is_active"] : 1,
                "slot_type"     => $row["slot_type"] ?? "unlimited",
                "duration_days" => $row["duration_days"],
                "price"         => $row["price"],
            ];
        }
        http_response_code(200);
        echo json_encode($plans_arr);
    }

    // POST /api/plans
    public function create() {
        $data = json_decode(file_get_contents("php://input"));

        if(
            !empty($data->court_id) &&
            !empty($data->name) &&
            !empty($data->price) &&
            !empty($data->duration_days)
        ) {
            if (!$this->authorizeCourt((int)$data->court_id)) return;
            $plan = new Plan();
            $plan->court_id      = $data->court_id;
            $plan->sub_court_id  = isset($data->sub_court_id) && $data->sub_court_id !== '' ? (int)$data->sub_court_id : null;
            $plan->name          = $data->name;
            $plan->description   = $data->description ?? '';
            $plan->slot_type     = $data->slot_type ?? 'unlimited';
            $plan->duration_days = $data->duration_days;
            $plan->price         = $data->price;
            $plan->benefits      = $data->benefits ?? '';
            $plan->is_active     = isset($data->is_active) && !$data->is_active ? 0 : 1;

            if($plan->create()) {
                http_response_code(201);
                echo json_encode(array("message" => "Plan was created."));
            } else {
                http_response_code(503);
                echo json_encode(array("message" => "Unable to create plan."));
            }
        } else {
            http_response_code(400);
            echo json_encode(array("message" => "Unable to create plan. Data is incomplete."));
        }
    }

    public function setActive(int $id): void {
        $user = Auth::require();
        $body = json_decode(file_get_contents('php://input'));
        $active = !empty($body->active) ? 1 : 0;
        $db = Database::getConnection();
        $stmt = $db->prepare('SELECT p.court_id, c.owner_id FROM plans p JOIN courts c ON c.id = p.court_id WHERE p.id = ?');
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            http_response_code(404);
            echo json_encode(['message' => 'Plan not found']);
            return;
        }
        if ((int)$row['owner_id'] !== (int)$user['id'] && ($user['role'] ?? '') !== 'admin') {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return;
        }
        $db->prepare('UPDATE plans SET is_active = ? WHERE id = ?')->execute([$active, $id]);
        echo json_encode(['is_active' => $active]);
    }

    // DELETE /api/plans/:id
    public function delete($id) {
        $db = Database::getConnection();
        $owner = $db->prepare('SELECT court_id FROM plans WHERE id = ?');
        $owner->execute([(int)$id]);
        $courtId = (int)$owner->fetchColumn();
        if (!$courtId) {
            http_response_code(404);
            echo json_encode(['message' => 'Plan not found.']);
            return;
        }
        if (!$this->authorizeCourt($courtId)) return;

        $plan = new Plan();
        $plan->id = $id;

        $activeCount = $plan->activeSubscriberCount();
        if ($activeCount > 0) {
            http_response_code(409);
            echo json_encode([
                "message" => "$activeCount active subscriber(s) are using this plan. Cancel their subscriptions before deleting."
            ]);
            return;
        }

        if ($plan->delete()) {
            http_response_code(200);
            echo json_encode(array("message" => "Plan deleted."));
        } else {
            http_response_code(503);
            echo json_encode(array("message" => "Unable to delete plan."));
        }
    }
}
