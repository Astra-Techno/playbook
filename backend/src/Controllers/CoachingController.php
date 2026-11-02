<?php

require_once __DIR__ . '/../CoachingSession.php';
require_once __DIR__ . '/../SlotLock.php';

class CoachingController
{
    public function index(int $courtId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->owns($db, $courtId, $authUser)) {
            return;
        }
        $stmt = $db->prepare('
            SELECT id, title, instructor_name, capacity, start_time, end_time, status, sub_court_id
            FROM coaching_sessions
            WHERE court_id = ?
            ORDER BY start_time DESC
            LIMIT 50
        ');
        $stmt->execute([$courtId]);
        $sessions = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $ids = array_map(static fn ($row) => (int)$row['id'], $sessions);
        $enrolled = [];
        if ($ids) {
            $in = implode(',', $ids);
            $players = $db->query("
                SELECT id, session_id, display_name, user_id, state, attendance
                FROM coaching_enrollments
                WHERE session_id IN ($in)
                ORDER BY id
            ");
            foreach ($players->fetchAll(PDO::FETCH_ASSOC) as $player) {
                $enrolled[(int)$player['session_id']][] = [
                    'id' => (int)$player['id'],
                    'display_name' => (string)$player['display_name'],
                    'user_id' => $player['user_id'] !== null ? (int)$player['user_id'] : null,
                    'state' => (string)$player['state'],
                    'attendance' => $player['attendance'],
                ];
            }
        }
        $rows = [];
        foreach ($sessions as $session) {
            $session['enrollments'] = $enrolled[(int)$session['id']] ?? [];
            $rows[] = $session;
        }
        echo json_encode(['sessions' => $rows]);
    }

    public function create(int $courtId): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        if (!$this->owns($db, $courtId, $authUser)) {
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $spaceId = $this->whole($input['sub_court_id'] ?? null);
        if ($spaceId !== null && $spaceId > 0) {
            $space = $db->prepare('SELECT id FROM sub_courts WHERE id = ? AND court_id = ?');
            $space->execute([$spaceId, $courtId]);
            if (!$space->fetchColumn()) {
                http_response_code(404);
                echo json_encode(['message' => 'Space not found']);
                return;
            }
        } else {
            $spaceId = null;
        }
        if (!SlotLock::hold($db, $courtId)) {
            http_response_code(409);
            echo json_encode(['message' => 'This time is being booked. Try again.']);
            return;
        }
        try {
            require_once __DIR__ . '/../Models/Booking.php';
            $start = trim((string)($input['start_time'] ?? ''));
            $end = trim((string)($input['end_time'] ?? ''));
            $slotFree = (new Booking())->isSlotAvailable($courtId, $start, $end, $spaceId);
            $plan = CoachingSession::plan(
                (string)($input['title'] ?? ''),
                (string)($input['instructor_name'] ?? ''),
                (int)($this->whole($input['capacity'] ?? null) ?? 0),
                $start,
                $end,
                $slotFree
            );
            if (!$plan['ok']) {
                http_response_code(422);
                echo json_encode(['message' => $plan['message']]);
                return;
            }
            $db->beginTransaction();
            $ins = $db->prepare('
                INSERT INTO coaching_sessions
                    (court_id, sub_court_id, title, instructor_name, capacity, start_time, end_time, status, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, \'scheduled\', ?)
            ');
            $ins->execute([$courtId, $spaceId, $plan['title'], $plan['instructor'], $plan['capacity'], $plan['start'], $plan['end'], $userId]);
            $sessionId = (int)$db->lastInsertId();
            $reason = function_exists('mb_substr') ? mb_substr($plan['title'], 0, 255) : substr($plan['title'], 0, 255);
            $block = $db->prepare('
                INSERT INTO blocked_slots
                    (court_id, sub_court_id, start_time, end_time, reason, blocked_by, block_kind, repeat_annually, coaching_session_id)
                VALUES (?, ?, ?, ?, ?, ?, \'coaching\', 0, ?)
            ');
            $block->execute([$courtId, $spaceId, $plan['start'], $plan['end'], $reason, $userId, $sessionId]);
            $db->commit();
            echo json_encode(['id' => $sessionId, 'status' => 'scheduled']);
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The class could not be saved.']);
        } finally {
            SlotLock::release($db, $courtId);
        }
    }

    public function cancel(int $sessionId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $session = $this->session($db, $sessionId, $authUser);
        if ($session === null) {
            return;
        }
        if (!CoachingSession::canCancel((string)$session['status'])) {
            http_response_code(422);
            echo json_encode(['message' => 'Only a scheduled class can be cancelled.']);
            return;
        }
        $db->beginTransaction();
        $upd = $db->prepare("UPDATE coaching_sessions SET status = 'cancelled' WHERE id = ? AND status = 'scheduled'");
        $upd->execute([$sessionId]);
        if (!$upd->rowCount()) {
            $db->rollBack();
            http_response_code(409);
            echo json_encode(['message' => 'Only a scheduled class can be cancelled.']);
            return;
        }
        $db->prepare('DELETE FROM blocked_slots WHERE coaching_session_id = ?')->execute([$sessionId]);
        $db->commit();
        echo json_encode(['status' => 'cancelled']);
    }

    public function enroll(int $sessionId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $session = $this->session($db, $sessionId, $authUser);
        if ($session === null) {
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $takenStmt = $db->prepare("SELECT user_id FROM coaching_enrollments WHERE session_id = ? AND state = 'enrolled'");
        $takenStmt->execute([$sessionId]);
        $ids = [];
        $taken = 0;
        foreach ($takenStmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $taken++;
            if ($row['user_id'] !== null && (int)$row['user_id'] > 0) {
                $ids[] = (int)$row['user_id'];
            }
        }
        $userId = $this->whole($input['user_id'] ?? null);
        $plan = CoachingSession::enroll((string)$session['status'], (int)$session['capacity'], $taken, (string)($input['display_name'] ?? ''), $userId, $ids);
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $ins = $db->prepare('INSERT INTO coaching_enrollments (session_id, user_id, display_name, state) VALUES (?, ?, ?, \'enrolled\')');
        $ins->execute([$sessionId, $plan['user_id'], $plan['name']]);
        echo json_encode(['id' => (int)$db->lastInsertId(), 'state' => 'enrolled']);
    }

    public function mark(int $sessionId, int $enrollmentId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $session = $this->session($db, $sessionId, $authUser);
        if ($session === null) {
            return;
        }
        $row = $db->prepare('SELECT id, state, attendance FROM coaching_enrollments WHERE id = ? AND session_id = ?');
        $row->execute([$enrollmentId, $sessionId]);
        $player = $row->fetch(PDO::FETCH_ASSOC);
        if (!$player) {
            http_response_code(404);
            echo json_encode(['message' => 'Player not found']);
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $plan = CoachingSession::attendance(
            (string)$session['status'],
            (string)$player['state'],
            $player['attendance'] !== null ? (string)$player['attendance'] : null,
            (string)($input['attendance'] ?? '')
        );
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $upd = $db->prepare('UPDATE coaching_enrollments SET attendance = ? WHERE id = ? AND attendance IS NULL');
        $upd->execute([$plan['attendance'], $enrollmentId]);
        if (!$upd->rowCount()) {
            http_response_code(409);
            echo json_encode(['message' => 'Attendance is already marked.']);
            return;
        }
        echo json_encode(['attendance' => $plan['attendance']]);
    }

    /** @param array<string,mixed> $authUser */
    private function owns(PDO $db, int $courtId, array $authUser): bool
    {
        $court = $db->prepare('SELECT id, owner_id FROM courts WHERE id = ?');
        $court->execute([$courtId]);
        $venue = $court->fetch(PDO::FETCH_ASSOC);
        if (!$venue) {
            http_response_code(404);
            echo json_encode(['message' => 'Venue not found']);
            return false;
        }
        $allowed = ($authUser['role'] ?? '') === 'admin' || (int)$venue['owner_id'] === (int)$authUser['id'];
        if (!$allowed) {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return false;
        }
        return true;
    }

    /** @param array<string,mixed> $authUser
     *  @return array<string,mixed>|null
     */
    private function session(PDO $db, int $sessionId, array $authUser): ?array
    {
        $stmt = $db->prepare('SELECT id, court_id, status, capacity FROM coaching_sessions WHERE id = ?');
        $stmt->execute([$sessionId]);
        $session = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$session) {
            http_response_code(404);
            echo json_encode(['message' => 'Class not found']);
            return null;
        }
        if (!$this->owns($db, (int)$session['court_id'], $authUser)) {
            return null;
        }
        return $session;
    }

    private function whole(mixed $value): ?int
    {
        if (is_int($value) && $value >= 0) {
            return $value;
        }
        if (is_string($value) && preg_match('/^\d+$/', $value) === 1) {
            return (int)$value;
        }
        return null;
    }
}
