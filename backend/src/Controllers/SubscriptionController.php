<?php
require_once __DIR__ . '/../Models/Subscription.php';
require_once __DIR__ . '/../Models/Plan.php';
require_once __DIR__ . '/../MembershipDirectory.php';
require_once __DIR__ . '/../AccountLookup.php';
require_once __DIR__ . '/../StaffAccess.php';
require_once __DIR__ . '/../MemberCheckIn.php';
require_once __DIR__ . '/../MembershipCare.php';

class SubscriptionController {

    // GET /subscriptions                       → list auth user's subscriptions
    // GET /subscriptions?court_id=Y            → check active sub for court
    public function index() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $court_id = isset($_GET['court_id']) ? (int)$_GET['court_id'] : null;

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
        $authUser     = Auth::requireOwner();
        $court_id     = (int)($_GET['court_id'] ?? 0);
        $sub_court_id = isset($_GET['sub_court_id']) ? (int)$_GET['sub_court_id'] : null;
        if (!$court_id) { http_response_code(400); echo json_encode(['message' => 'court_id required']); return; }

        // The owner, or a manager at this venue
        $db  = Database::getConnection();
        if (!StaffAccess::canAtVenue($db, $court_id, $authUser, 'members')) { http_response_code(403); echo json_encode(['error' => 'Forbidden']); return; }
        MemberCheckIn::ensureSchema($db);

        $db = Database::getConnection();

        if ($sub_court_id !== null) {
            $stmt = $db->prepare("
                SELECT us.id, us.user_id, us.plan_id, us.status, us.start_date, us.end_date,
                       us.slot_type, us.frozen_from, us.frozen_until, us.freeze_days_used, u.name AS user_name,
                       p.name AS plan_name, p.price AS plan_price,
                       (SELECT COUNT(*) FROM member_visits mv WHERE mv.subscription_id = us.id AND mv.visit_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')) AS visits_this_month,
                       (SELECT MAX(mv.visited_at) FROM member_visits mv WHERE mv.subscription_id = us.id) AS last_visit
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
                       us.slot_type, us.frozen_from, us.frozen_until, us.freeze_days_used, u.name AS user_name,
                       p.name AS plan_name, p.price AS plan_price, p.sub_court_id,
                       (SELECT COUNT(*) FROM member_visits mv WHERE mv.subscription_id = us.id AND mv.visit_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')) AS visits_this_month,
                       (SELECT MAX(mv.visited_at) FROM member_visits mv WHERE mv.subscription_id = us.id) AS last_visit
                FROM user_subscriptions us
                JOIN users u  ON u.id  = us.user_id
                JOIN plans p  ON p.id  = us.plan_id
                WHERE us.court_id = ? AND us.status = 'active'
                ORDER BY us.end_date ASC
            ");
            $stmt->execute([$court_id]);
        }

        $members = array_map([MembershipDirectory::class, 'row'], $stmt->fetchAll(PDO::FETCH_ASSOC));
        http_response_code(200);
        echo json_encode(['members' => $members, 'count' => count($members)]);
    }

    // PUT /subscriptions/:id/cancel
    public function cancel($id) {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $role     = $authUser['role'];

        $db = Database::getConnection();
        // Migrate: add cancelled_at column if missing
        try { $db->exec("ALTER TABLE user_subscriptions ADD COLUMN cancelled_at DATETIME DEFAULT NULL"); } catch (\PDOException $e) {}

        // Check: subscription owner, court owner (for their courts), or admin
        $chk = $db->prepare(
            "SELECT us.id FROM user_subscriptions us
             JOIN courts c ON c.id = us.court_id
             WHERE us.id = ? AND us.status = 'active'
               AND (us.user_id = ? OR c.owner_id = ? OR ? = 'admin')"
        );
        $chk->execute([$id, $user_id, $user_id, $role]);
        if (!$chk->fetch()) {
            http_response_code(404);
            echo json_encode(['message' => 'Subscription not found or already cancelled']);
            return;
        }

        $db->prepare("UPDATE user_subscriptions SET status='cancelled', cancelled_at=NOW() WHERE id=?")->execute([$id]);
        http_response_code(200);
        echo json_encode(['message' => 'Subscription cancelled. Access continues until the end date.']);
    }

    // POST /subscriptions/renew { subscription_id }
    // Creates a new subscription starting from today (or end_date if still active), same plan
    public function renew() {
        $authUser = Auth::require();
        $authId   = (int)$authUser['id'];
        $data     = json_decode(file_get_contents("php://input"));
        $sub_id   = (int)($data->subscription_id ?? 0);
        if (!$sub_id) { http_response_code(400); echo json_encode(['message' => 'subscription_id required']); return; }

        $db = Database::getConnection();
        // Fetch existing subscription + plan details
        $stmt = $db->prepare(
            "SELECT us.*, p.price AS plan_price, p.duration_days, p.slot_type AS plan_slot_type, p.name AS plan_name
             FROM user_subscriptions us
             JOIN plans p ON p.id = us.plan_id
             WHERE us.id = ?"
        );
        $stmt->execute([$sub_id]);
        $existing = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$existing) { http_response_code(404); echo json_encode(['message' => 'Subscription not found']); return; }

        // Only the subscription owner or admin can renew
        if ((int)$existing['user_id'] !== $authId && $authUser['role'] !== 'admin') {
            http_response_code(403); echo json_encode(['error' => 'Forbidden']); return;
        }

        if ((float)$existing['plan_price'] > 0 && $authUser['role'] !== 'admin') {
            http_response_code(409); echo json_encode(['message' => 'Renew paid plans through checkout']); return;
        }
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

    // POST /subscriptions { plan_id }
    public function create() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $data     = json_decode(file_get_contents("php://input"));

        if (empty($data->plan_id)) {
            http_response_code(400);
            echo json_encode(["message" => "plan_id required"]);
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

        if ((float)$planRow['price'] > 0 && $authUser['role'] !== 'admin') {
            http_response_code(409); echo json_encode(['message' => 'Purchase paid plans through checkout']); return;
        }
        $sub = new Subscription();

        // Check for duplicate active subscription
        $existing = $sub->getActive($user_id, (int)$planRow['court_id']);
        if ($existing && Subscription::coversSlot($existing['slot_type'], $planRow['slot_type'])) {
            http_response_code(409);
            echo json_encode(["message" => "You already have an active subscription covering these slots"]);
            return;
        }

        if ($sub->create(
            $user_id,
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

    // POST /subscriptions/desk { plan_id, phone }
    // The venue records a membership for someone standing at the desk. No online checkout.
    public function desk() {
        $authUser = Auth::require();
        $data = json_decode(file_get_contents('php://input'));
        $planId = (int)($data->plan_id ?? 0);
        $phone = trim((string)($data->phone ?? ''));
        if (!$planId || $phone === '') {
            http_response_code(400);
            echo json_encode(['message' => 'plan_id and phone are required']);
            return;
        }
        $db = Database::getConnection();
        $stmt = $db->prepare('SELECT * FROM plans WHERE id = ?');
        $stmt->execute([$planId]);
        $planRow = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$planRow) {
            http_response_code(404);
            echo json_encode(['message' => 'Plan not found']);
            return;
        }
        if (!StaffAccess::canAtVenue($db, (int)$planRow['court_id'], $authUser, 'members')) {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return;
        }
        $player = AccountLookup::byPhone($db, $phone);
        if (!$player) {
            http_response_code(404);
            echo json_encode(['message' => 'No KoCourt account for this number. They must sign in to KoCourt once with this phone first.']);
            return;
        }
        $sub = new Subscription();
        $userId = (int)$player['id'];
        $existing = $sub->getActive($userId, (int)$planRow['court_id']);
        if ($existing && Subscription::coversSlot($existing['slot_type'], $planRow['slot_type'])) {
            http_response_code(409);
            echo json_encode(['message' => 'This player already has an active membership covering these slots']);
            return;
        }
        if ($sub->create($userId, $planId, (int)$planRow['court_id'], $planRow['slot_type'], (int)$planRow['duration_days'])) {
            http_response_code(201);
            echo json_encode(['message' => $player['name'] . ' is now a member']);
            return;
        }
        http_response_code(503);
        echo json_encode(['message' => 'Unable to create subscription']);
    }

    // GET /subscriptions/:id/check-in-code — the member's door pass (QR)
    public function checkInCode(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        MemberCheckIn::ensureSchema($db);
        $stmt = $db->prepare('SELECT id, user_id, status, start_date, end_date, check_in_code FROM user_subscriptions WHERE id = ?');
        $stmt->execute([$id]);
        $sub = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$sub || (int)$sub['user_id'] !== (int)$authUser['id']) {
            http_response_code(404); echo json_encode(['message' => 'Membership not found']); return;
        }
        if ($sub['status'] !== 'active') {
            http_response_code(409); echo json_encode(['message' => 'Only an active membership has a pass.']); return;
        }
        $code = MemberCheckIn::ensureCode($db, $id, $sub['check_in_code']);
        $visits = $db->prepare("SELECT COUNT(*) FROM member_visits WHERE subscription_id = ? AND visit_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')");
        $visits->execute([$id]);
        echo json_encode([
            'payload' => MemberCheckIn::payload($id, $code),
            'code' => $code,
            'visits_this_month' => (int)$visits->fetchColumn(),
        ]);
    }

    // POST /subscriptions/check-in-scan { payload } — venue staff scan a member at the door
    public function scanCheckIn(): void
    {
        $authUser = Auth::require();
        $data = json_decode(file_get_contents('php://input'));
        $scan = MemberCheckIn::parse((string)($data->payload ?? ''));
        if (!$scan) {
            http_response_code(422); echo json_encode(['message' => 'This is not a KoCourt member pass.']); return;
        }
        $db = Database::getConnection();
        MemberCheckIn::ensureSchema($db);
        $stmt = $db->prepare("
            SELECT us.id, us.user_id, us.court_id, us.status, us.start_date, us.end_date, us.check_in_code,
                   us.frozen_from, us.frozen_until,
                   u.name AS member_name, p.name AS plan_name, c.name AS venue_name
            FROM user_subscriptions us
            JOIN users u ON u.id = us.user_id
            JOIN plans p ON p.id = us.plan_id
            JOIN courts c ON c.id = us.court_id
            WHERE us.id = ?
        ");
        $stmt->execute([$scan['id']]);
        $sub = $stmt->fetch(PDO::FETCH_ASSOC);
        // Permission first, so a scan at the wrong venue reveals nothing about the member.
        if (!$sub || !StaffAccess::canAtVenue($db, (int)$sub['court_id'], $authUser, 'attendance')) {
            http_response_code(404); echo json_encode(['message' => 'This pass is not for a venue you manage.']); return;
        }
        if (!MemberCheckIn::matches($sub['check_in_code'], $scan['code'])) {
            http_response_code(422); echo json_encode(['message' => 'This pass code does not match the membership.']); return;
        }

        $now = new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata'));
        $today = $now->format('Y-m-d');
        $member = [
            'id' => (int)$sub['id'],
            'member' => $sub['member_name'] ?: 'Member',
            'plan' => $sub['plan_name'],
            'venue' => $sub['venue_name'],
            'end_date' => substr((string)$sub['end_date'], 0, 10),
            'days_left' => MemberCheckIn::daysLeft((string)$sub['end_date'], $today),
        ];
        if (MembershipCare::isFrozen($sub['frozen_from'], $sub['frozen_until'], $today)) {
            http_response_code(422);
            echo json_encode(['message' => 'This membership is frozen until ' . substr((string)$sub['frozen_until'], 0, 10) . '. End the freeze in Members to let them in.', 'member' => $member]);
            return;
        }
        $decision = MemberCheckIn::decide((string)$sub['status'], (string)$sub['start_date'], (string)$sub['end_date'], $today);
        if (!$decision['ok']) {
            http_response_code(422); echo json_encode(['message' => $decision['message'], 'member' => $member]); return;
        }

        // One visit per member per day; a second scan the same day is fine, just not counted twice.
        $ins = $db->prepare('INSERT IGNORE INTO member_visits (subscription_id, user_id, court_id, visit_date, visited_at, checked_in_by) VALUES (?,?,?,?,?,?)');
        $ins->execute([(int)$sub['id'], (int)$sub['user_id'], (int)$sub['court_id'], $today, $now->format('Y-m-d H:i:s'), (int)$authUser['id']]);
        $already = $ins->rowCount() === 0;
        $visits = $db->prepare("SELECT COUNT(*) FROM member_visits WHERE subscription_id = ? AND visit_date >= ?");
        $visits->execute([(int)$sub['id'], $now->format('Y-m-01')]);
        $member['visits_this_month'] = (int)$visits->fetchColumn();
        echo json_encode([
            'message' => $already ? 'Already checked in today.' : 'Checked in.',
            'already' => $already,
            'member' => $member,
        ]);
    }

    /** A membership at a venue where this user may manage members, or null after a 404. */
    private function venueSubscription(PDO $db, int $id, array $authUser): ?array
    {
        MemberCheckIn::ensureSchema($db);
        $stmt = $db->prepare('SELECT us.*, c.name AS venue_name FROM user_subscriptions us JOIN courts c ON c.id = us.court_id WHERE us.id = ?');
        $stmt->execute([$id]);
        $sub = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$sub || !StaffAccess::canAtVenue($db, (int)$sub['court_id'], $authUser, 'members')) {
            http_response_code(404); echo json_encode(['message' => 'Membership not found']);
            return null;
        }
        return $sub;
    }

    private static function today(): string
    {
        return (new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata')))->format('Y-m-d');
    }

    /** In-app notification plus push, at most once per $eventKey. */
    private static function tellMember(PDO $db, array $sub, string $type, string $title, string $body, string $eventKey): bool
    {
        $ins = $db->prepare('INSERT IGNORE INTO user_notifications (user_id, type, title, body, court_id, event_key) VALUES (?,?,?,?,?,?)');
        $ins->execute([(int)$sub['user_id'], $type, $title, $body, (int)$sub['court_id'], $eventKey]);
        if (!$ins->rowCount()) {
            return false;
        }
        require_once __DIR__ . '/../Push.php';
        Push::sendToUser((int)$sub['user_id'], $title, $body, ['type' => $type, 'subscription_id' => (string)$sub['id']]);
        return true;
    }

    // POST /subscriptions/:id/freeze { days } — owner or manager pauses a membership
    public function freeze(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $sub = $this->venueSubscription($db, $id, $authUser);
        if ($sub === null) return;
        $data = json_decode(file_get_contents('php://input'));
        $today = self::today();
        $plan = MembershipCare::freeze((string)$sub['status'], (string)$sub['end_date'], $sub['frozen_until'], (int)($sub['freeze_days_used'] ?? 0), (int)($data->days ?? 0), $today);
        if (!$plan['ok']) {
            http_response_code(422); echo json_encode(['message' => $plan['message']]); return;
        }
        // end_date in the WHERE guards against two desks freezing at once.
        $upd = $db->prepare('UPDATE user_subscriptions SET frozen_from = ?, frozen_until = ?, end_date = ?, freeze_days_used = ? WHERE id = ? AND end_date = ?');
        $upd->execute([$plan['from'], $plan['until'], $plan['end'], $plan['used'], $id, $sub['end_date']]);
        if (!$upd->rowCount()) {
            http_response_code(409); echo json_encode(['message' => 'This membership just changed. Refresh and try again.']); return;
        }
        $until = (new DateTimeImmutable($plan['until']))->format('j M');
        self::tellMember($db, $sub, 'membership', "Your {$sub['venue_name']} membership is paused", "Frozen until $until. Your end date moved to " . (new DateTimeImmutable($plan['end']))->format('j M') . '.', "freeze:$id:{$plan['from']}");
        echo json_encode(['message' => $plan['message'], 'frozen_until' => $plan['until'], 'end_date' => $plan['end']]);
    }

    // POST /subscriptions/:id/unfreeze — end a freeze today and give back unused days
    public function unfreeze(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $sub = $this->venueSubscription($db, $id, $authUser);
        if ($sub === null) return;
        $plan = MembershipCare::unfreeze($sub['frozen_from'], $sub['frozen_until'], (string)$sub['end_date'], (int)($sub['freeze_days_used'] ?? 0), self::today());
        if (!$plan['ok']) {
            http_response_code(422); echo json_encode(['message' => $plan['message']]); return;
        }
        $upd = $db->prepare('UPDATE user_subscriptions SET frozen_from = ?, frozen_until = ?, end_date = ?, freeze_days_used = ? WHERE id = ? AND end_date = ?');
        $upd->execute([$plan['from'], $plan['until'], $plan['end'], $plan['used'], $id, $sub['end_date']]);
        if (!$upd->rowCount()) {
            http_response_code(409); echo json_encode(['message' => 'This membership just changed. Refresh and try again.']); return;
        }
        echo json_encode(['message' => $plan['message'], 'end_date' => $plan['end']]);
    }

    // POST /subscriptions/:id/remind — owner or manager nudges a member, once a day
    public function remind(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $sub = $this->venueSubscription($db, $id, $authUser);
        if ($sub === null) return;
        if ($sub['status'] !== 'active') {
            http_response_code(422); echo json_encode(['message' => 'Only active members can be reminded.']); return;
        }
        $today = self::today();
        $msg = MembershipCare::reminder((string)$sub['venue_name'], (string)$sub['end_date'], $today);
        $sent = self::tellMember($db, $sub, 'membership', $msg['title'], $msg['body'], "member:$id:$today");
        echo json_encode(['sent' => $sent, 'kind' => $msg['kind'], 'message' => $sent ? 'Reminder sent' : 'Already reminded today']);
    }
}
