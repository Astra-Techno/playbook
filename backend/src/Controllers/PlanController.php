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

        $plan = new Plan();
        $stmt = $plan->readByCourt($court_id, $sub_court_id);

        $plans_arr = ["records" => []];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $plans_arr["records"][] = [
                "id"            => $row["id"],
                "court_id"      => $row["court_id"],
                "sub_court_id"  => $row["sub_court_id"] ?? null,
                "name"          => $row["name"],
                "description"   => $row["description"],
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
