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

    // GET /subscriptions/members?court_id=X[&sub_court_id=Y]
    // Returns all active subscribers for a venue or specific space's plans
    public function members() {
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        $db = Database::getConnection();

        if ($sub_court_id !== null) {
            $stmt = $db->prepare("
                SELECT us.id, us.user_id, us.plan_id, us.status, us.start_date, us.end_date,
                       us.slot_type, u.name AS user_name, u.phone AS user_phone,
                       p.name AS plan_name, p.price AS plan_price
                FROM user_subscriptions us
                JOIN users u  ON u.id  = us.user_id
                JOIN plans p  ON p.id  = us.plan_id
                WHERE us.court_id = ? AND p.sub_court_id = ? AND us.status = 'active'
                ORDER BY us.end_date ASC
            ");
            $stmt->execute([$court_id, $sub_court_id]);
        } else {
            $stmt = $db->prepare("
                SELECT us.id, us.user_id, us.plan_id, us.status, us.start_date, us.end_date,
                       us.slot_type, u.name AS user_name, u.phone AS user_phone,
                       p.name AS plan_name, p.price AS plan_price, p.sub_court_id
                FROM user_subscriptions us
                JOIN users u  ON u.id  = us.user_id
                JOIN plans p  ON p.id  = us.plan_id
                WHERE us.court_id = ? AND us.status = 'active'
                ORDER BY us.end_date ASC
            ");
            $stmt->execute([$court_id]);
        }

        $members = $stmt->fetchAll(PDO::FETCH_ASSOC);
        http_response_code(200);
        echo json_encode(['members' => $members, 'count' => count($members)]);
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

    // POST /subscriptions/renew { subscription_id }
    // Creates a new subscription starting from today (or end_date if still active), same plan
    public function renew() {
        $data = json_decode(file_get_contents("php://input"));
        $sub_id = (int)($data->subscription_id ?? 0);
        if (!$sub_id) { http_response_code(400); echo json_encode(['message' => 'subscription_id required']); return; }

        $db = Database::getConnection();
        // Fetch existing subscription + plan details
        $stmt = $db->prepare(
            "SELECT us.*, p.duration_days, p.slot_type AS plan_slot_type, p.name AS plan_name
             FROM user_subscriptions us
             JOIN plans p ON p.id = us.plan_id
             WHERE us.id = ?"
        );
        $stmt->execute([$sub_id]);
        $existing = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$existing) { http_response_code(404); echo json_encode(['message' => 'Subscription not found']); return; }

        $duration = (int)$existing['duration_days'];
        $today    = date('Y-m-d');
        // Start from end_date if still active and in the future, else from today
        $endDate  = $existing['end_date'];
        $startFrom = ($existing['status'] === 'active' && $endDate >= $today) ? $endDate : $today;
        $newEnd   = date('Y-m-d', strtotime("+{$duration} days", strtotime($startFrom)));

        $ins = $db->prepare(
            "INSERT INTO user_subscriptions (user_id, plan_id, court_id, slot_type, start_date, end_date, status)
             VALUES (?, ?, ?, ?, ?, ?, 'active')"
        );
        $ins->execute([
            $existing['user_id'],
            $existing['plan_id'],
            $existing['court_id'],
            $existing['slot_type'],
            $startFrom,
            $newEnd,
        ]);
        $newId = $db->lastInsertId();
        http_response_code(201);
        echo json_encode([
            'message'   => 'Subscription renewed!',
            'id'        => $newId,
            'start_date'=> $startFrom,
            'end_date'  => $newEnd,
            'plan_name' => $existing['plan_name'],
        ]);
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
