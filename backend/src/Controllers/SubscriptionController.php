<?php
require_once __DIR__ . '/../Models/Subscription.php';
require_once __DIR__ . '/../Models/Plan.php';

class SubscriptionController {

    // GET /subscriptions?user_id=X             → list user's subscriptions
    // GET /subscriptions?user_id=X&court_id=Y  → check active sub for court
    public function index() {
        $user_id  = isset($_GET['user_id'])  ? (int)$_GET['user_id']  : null;
        $court_id = isset($_GET['court_id']) ? (int)$_GET['court_id'] : null;

        if (!$user_id) {
            http_response_code(400);
            echo json_encode(["message" => "user_id required"]);
            return;
        }

        $sub = new Subscription();

        if ($court_id) {
            // Check single court active subscription
            $active = $sub->getActive($user_id, $court_id);
            http_response_code(200);
            echo json_encode(["active" => $active ?: null]);
        } else {
            $records = $sub->listByUser($user_id);
            http_response_code(200);
            echo json_encode(["records" => $records]);
        }
    }

    // PUT /subscriptions/:id/cancel  { user_id }
    public function cancel($id) {
        $data    = json_decode(file_get_contents("php://input"));
        $user_id = (int)($data->user_id ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }

        $db = Database::getConnection();
        // Migrate: add cancelled_at column if missing
        try { $db->exec("ALTER TABLE user_subscriptions ADD COLUMN cancelled_at DATETIME DEFAULT NULL"); } catch (\PDOException $e) {}

        $stmt = $db->prepare(
            "UPDATE user_subscriptions SET status='cancelled', cancelled_at=NOW()
             WHERE id=? AND user_id=? AND status='active'"
        );
        $stmt->execute([$id, $user_id]);
        if ($stmt->rowCount() === 0) {
            http_response_code(404);
            echo json_encode(['message' => 'Subscription not found or already cancelled']);
            return;
        }
        http_response_code(200);
        echo json_encode(['message' => 'Subscription cancelled. Access continues until the end date.']);
    }

    // POST /subscriptions { user_id, plan_id }
    public function create() {
        $data = json_decode(file_get_contents("php://input"));

        if (empty($data->user_id) || empty($data->plan_id)) {
            http_response_code(400);
            echo json_encode(["message" => "user_id and plan_id required"]);
            return;
        }

        // Fetch plan details via shared PDO connection
        $db   = Database::getConnection();
        $stmt = $db->prepare("SELECT * FROM plans WHERE id=?");
        $stmt->execute([(int)$data->plan_id]);
        $planRow = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$planRow) {
            http_response_code(404);
            echo json_encode(["message" => "Plan not found"]);
            return;
        }

        $sub = new Subscription();

        // Check for duplicate active subscription
        $existing = $sub->getActive((int)$data->user_id, (int)$planRow['court_id']);
        if ($existing && Subscription::coversSlot($existing['slot_type'], $planRow['slot_type'])) {
            http_response_code(409);
            echo json_encode(["message" => "You already have an active subscription covering these slots"]);
            return;
        }

        if ($sub->create(
            (int)$data->user_id,
            (int)$data->plan_id,
            (int)$planRow['court_id'],
            $planRow['slot_type'],
            (int)$planRow['duration_days']
        )) {
            http_response_code(201);
            echo json_encode(["message" => "Subscribed successfully!"]);
        } else {
            http_response_code(503);
            echo json_encode(["message" => "Unable to create subscription"]);
        }
    }
}
