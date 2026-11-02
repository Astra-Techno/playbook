<?php

require_once __DIR__ . '/../TournamentDraft.php';
require_once __DIR__ . '/../TournamentCategory.php';
require_once __DIR__ . '/../TournamentRegistration.php';
require_once __DIR__ . '/../TournamentPublish.php';
require_once __DIR__ . '/../TournamentParticipantExport.php';
require_once __DIR__ . '/../TournamentCheckIn.php';
require_once __DIR__ . '/../TournamentAnnouncement.php';
require_once __DIR__ . '/../TournamentRoster.php';
require_once __DIR__ . '/../TournamentApproval.php';
require_once __DIR__ . '/../TournamentDraw.php';
require_once __DIR__ . '/../SlotLock.php';

final class TournamentController
{
    public function index(): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $stmt = $db->prepare("
            SELECT t.id, t.title, t.sport, t.court_id, t.start_time, t.end_time,
                   t.timezone, t.status, t.visibility, t.registration_deadline, t.created_by
            FROM tournaments t
            JOIN tournament_organizers o ON o.tournament_id = t.id
            WHERE o.user_id = ?
            ORDER BY t.id DESC
        ");
        $stmt->execute([$userId]);
        echo json_encode(['tournaments' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    public function create(): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $draft = TournamentDraft::fromInput($input, $userId);
        if (!$draft['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $draft['message']]);
            return;
        }

        $db = Database::getConnection();
        $row = $draft['tournament'];
        if ($row['court_id'] !== null) {
            $court = $db->prepare('SELECT id FROM courts WHERE id = ?');
            $court->execute([$row['court_id']]);
            if (!$court->fetchColumn()) {
                http_response_code(422);
                echo json_encode(['message' => 'That venue was not found.']);
                return;
            }
        }

        $db->beginTransaction();
        try {
            $stmt = $db->prepare("
                INSERT INTO tournaments
                    (title, sport, court_id, start_time, end_time, timezone, status, visibility, source_type, registration_deadline, sponsor_name, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $row['title'],
                $row['sport'],
                $row['court_id'],
                $row['start_time'],
                $row['end_time'],
                $row['timezone'],
                $row['status'],
                $row['visibility'],
                $row['source_type'],
                $row['registration_deadline'],
                $row['sponsor_name'],
                $row['created_by'],
            ]);
            $id = (int)$db->lastInsertId();
            $org = $db->prepare("INSERT INTO tournament_organizers (tournament_id, user_id, role) VALUES (?, ?, ?)");
            $org->execute([$id, $draft['organizer']['user_id'], $draft['organizer']['role']]);
            $db->commit();
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The event could not be saved.']);
            return;
        }

        http_response_code(201);
        echo json_encode([
            'id' => $id,
            'status' => 'draft',
            'message' => 'Draft event saved.',
        ]);
    }

    public function categories(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $id, (int)$authUser['id'])) {
            return;
        }
        $stmt = $db->prepare("
            SELECT id, name, format, eligibility, fee, capacity, waitlist, approval
            FROM tournament_categories
            WHERE tournament_id = ?
            ORDER BY id
        ");
        $stmt->execute([$id]);
        echo json_encode(['categories' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    public function addCategory(int $id): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $draft = TournamentCategory::fromInput($input, $id);
        if (!$draft['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $draft['message']]);
            return;
        }
        $db = Database::getConnection();
        if (!$this->organizerDraft($db, $id, $userId)) {
            return;
        }
        $row = $draft['category'];
        $stmt = $db->prepare("
            INSERT INTO tournament_categories
                (tournament_id, name, format, eligibility, fee, capacity, waitlist, approval)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $row['tournament_id'],
            $row['name'],
            $row['format'],
            $row['eligibility'],
            $row['fee'],
            $row['capacity'],
            $row['waitlist'],
            $row['approval'],
        ]);
        http_response_code(201);
        echo json_encode([
            'id' => (int)$db->lastInsertId(),
            'message' => 'Category saved.',
        ]);
    }

    private function organizerDraft(PDO $db, int $id, int $userId): bool
    {
        $stmt = $db->prepare('SELECT status FROM tournaments WHERE id = ?');
        $stmt->execute([$id]);
        $status = $stmt->fetchColumn();
        if ($status === false) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return false;
        }
        $org = $db->prepare('SELECT id FROM tournament_organizers WHERE tournament_id = ? AND user_id = ?');
        $org->execute([$id, $userId]);
        if (!$org->fetchColumn()) {
            http_response_code(403);
            echo json_encode(['message' => 'Only an organizer can change this event']);
            return false;
        }
        if ($status !== 'draft') {
            http_response_code(422);
            echo json_encode(['message' => 'Categories stay as saved once the event leaves draft.']);
            return false;
        }
        return true;
    }

    public function registrations(int $tournamentId, int $categoryId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id'])) {
            return;
        }
        if (!$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        $stmt = $db->prepare("
            SELECT id, captain_user_id, state, fee_amount, idempotency_key, check_in_code, checked_in_at, created_at
            FROM tournament_registrations
            WHERE category_id = ?
            ORDER BY id
        ");
        $stmt->execute([$categoryId]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if ($rows) {
            $ids = array_map(static fn (array $row): int => (int)$row['id'], $rows);
            $marks = implode(',', array_fill(0, count($ids), '?'));
            $partners = $db->prepare("SELECT registration_id, display_name FROM tournament_registration_members WHERE registration_id IN ($marks) AND display_name IS NOT NULL AND display_name <> ''");
            $partners->execute($ids);
            $byEntry = [];
            foreach ($partners->fetchAll(PDO::FETCH_ASSOC) as $partner) {
                $byEntry[(int)$partner['registration_id']][] = $partner['display_name'];
            }
            foreach ($rows as &$row) {
                $row['partners'] = $byEntry[(int)$row['id']] ?? [];
            }
            unset($row);
        }
        echo json_encode(['registrations' => $rows]);
    }

    public function register(int $tournamentId, int $categoryId): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $key = TournamentRegistration::idempotencyKey($input['idempotency_key'] ?? null);
        if ($key === false) {
            http_response_code(422);
            echo json_encode(['message' => 'idempotency_key must be 8 to 64 letters, numbers, _ or -.']);
            return;
        }

        $db = Database::getConnection();
        $event = $db->prepare('SELECT status FROM tournaments WHERE id = ?');
        $event->execute([$tournamentId]);
        $eventStatus = $event->fetchColumn();
        if ($eventStatus === false) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return;
        }
        if ($eventStatus === 'cancelled') {
            http_response_code(422);
            echo json_encode(['message' => 'This event is not taking entries.']);
            return;
        }

        $existing = $db->prepare('SELECT id, category_id, captain_user_id, state, check_in_code FROM tournament_registrations WHERE idempotency_key = ?');
        $existing->execute([$key]);
        $prior = $existing->fetch(PDO::FETCH_ASSOC);
        if ($prior) {
            if ((int)$prior['category_id'] === $categoryId && (int)$prior['captain_user_id'] === $userId) {
                echo json_encode([
                    'id' => (int)$prior['id'],
                    'state' => $prior['state'],
                    'check_in_code' => $prior['check_in_code'],
                    'message' => 'Entry already saved.',
                ]);
                return;
            }
            http_response_code(409);
            echo json_encode(['message' => 'That idempotency_key is already used.']);
            return;
        }

        $now = (new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata')))->format('Y-m-d H:i:s');
        $db->beginTransaction();
        try {
            $cat = $db->prepare('SELECT id, tournament_id, format, fee, capacity, waitlist, approval FROM tournament_categories WHERE id = ? FOR UPDATE');
            $cat->execute([$categoryId]);
            $category = $cat->fetch(PDO::FETCH_ASSOC);
            if (!$category || (int)$category['tournament_id'] !== $tournamentId) {
                $db->rollBack();
                http_response_code(404);
                echo json_encode(['message' => 'Category not found']);
                return;
            }
            $dup = $db->prepare("SELECT id FROM tournament_registrations WHERE category_id = ? AND captain_user_id = ? AND state <> 'cancelled'");
            $dup->execute([$categoryId, $userId]);
            $already = (bool)$dup->fetchColumn();
            $taken = $this->seatsTaken($db, $categoryId, $now);
            $roster = TournamentRoster::extras((string)$category['format'], $input['members'] ?? [], $userId);
            if (!$roster['ok']) {
                $db->rollBack();
                http_response_code(422);
                echo json_encode(['message' => $roster['message']]);
                return;
            }
            $decision = TournamentRegistration::decide(
                (int)$category['capacity'],
                $taken,
                (int)$category['waitlist'] === 1,
                (float)$category['fee'],
                $already,
                (int)$category['approval'] === 1
            );
            if (!$decision['ok']) {
                $db->rollBack();
                http_response_code(409);
                echo json_encode(['message' => $decision['message']]);
                return;
            }
            $ins = $db->prepare("
                INSERT INTO tournament_registrations
                    (category_id, captain_user_id, state, fee_amount, idempotency_key, check_in_code)
                VALUES (?, ?, ?, ?, ?, ?)
            ");
            $code = '';
            $registrationId = 0;
            for ($attempt = 0; $attempt < 5; $attempt++) {
                $code = TournamentCheckIn::code();
                try {
                    $ins->execute([$categoryId, $userId, $decision['state'], $category['fee'], $key, $code]);
                    $registrationId = (int)$db->lastInsertId();
                    break;
                } catch (PDOException $e) {
                    if ($attempt === 4 || !str_contains($e->getMessage(), 'uq_registration_code')) {
                        throw $e;
                    }
                }
            }
            $member = $db->prepare("
                INSERT INTO tournament_registration_members (registration_id, user_id, confirm_state)
                VALUES (?, ?, 'confirmed')
            ");
            $member->execute([$registrationId, $userId]);
            $partner = $db->prepare("
                INSERT INTO tournament_registration_members (registration_id, user_id, display_name, confirm_state)
                VALUES (?, ?, ?, 'confirmed')
            ");
            foreach ($roster['members'] as $extra) {
                $partner->execute([$registrationId, $extra['user_id'], $extra['display_name']]);
            }
            if ($decision['hold']) {
                $hold = $db->prepare("
                    INSERT INTO tournament_capacity_holds (category_id, request_key, quantity, expires_at, state)
                    VALUES (?, ?, 1, ?, 'active')
                ");
                $hold->execute([$categoryId, $key, TournamentRegistration::expiresAt($now)]);
            }
            $db->commit();
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The entry could not be saved.']);
            return;
        }

        http_response_code(201);
        echo json_encode([
            'id' => $registrationId,
            'state' => $decision['state'],
            'check_in_code' => $code,
            'message' => 'Entry saved.',
        ]);
    }

    private function seatsTaken(PDO $db, int $categoryId, string $now): int
    {
        $stmt = $db->prepare("
            SELECT r.state, h.state AS hold_state, h.expires_at
            FROM tournament_registrations r
            LEFT JOIN tournament_capacity_holds h
              ON h.category_id = r.category_id AND h.request_key = r.idempotency_key
            WHERE r.category_id = ?
        ");
        $stmt->execute([$categoryId]);
        $taken = 0;
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            if (TournamentRegistration::countsAsSeat($row['state'], $row['hold_state'], $row['expires_at'], $now)) {
                $taken++;
            }
        }
        return $taken;
    }

    private function organizerOf(PDO $db, int $id, int $userId): bool
    {
        $stmt = $db->prepare('SELECT id FROM tournaments WHERE id = ?');
        $stmt->execute([$id]);
        if (!$stmt->fetchColumn()) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return false;
        }
        $org = $db->prepare('SELECT id FROM tournament_organizers WHERE tournament_id = ? AND user_id = ?');
        $org->execute([$id, $userId]);
        if (!$org->fetchColumn()) {
            http_response_code(403);
            echo json_encode(['message' => 'Only an organizer can view entries']);
            return false;
        }
        return true;
    }

    private function categoryInEvent(PDO $db, int $tournamentId, int $categoryId): bool
    {
        $stmt = $db->prepare('SELECT id FROM tournament_categories WHERE id = ? AND tournament_id = ?');
        $stmt->execute([$categoryId, $tournamentId]);
        if (!$stmt->fetchColumn()) {
            http_response_code(404);
            echo json_encode(['message' => 'Category not found']);
            return false;
        }
        return true;
    }

    public function publish(int $id): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $stmt = $db->prepare('SELECT id, title, status, court_id, start_time, end_time FROM tournaments WHERE id = ?');
        $stmt->execute([$id]);
        $event = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$event) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return;
        }
        $org = $db->prepare('SELECT id FROM tournament_organizers WHERE tournament_id = ? AND user_id = ?');
        $org->execute([$id, $userId]);
        if (!$org->fetchColumn()) {
            http_response_code(403);
            echo json_encode(['message' => 'Only an organizer can publish this event']);
            return;
        }

        $courtId = $event['court_id'] !== null && $event['court_id'] !== '' ? (int)$event['court_id'] : null;
        $start = $event['start_time'] !== null ? (string)$event['start_time'] : null;
        $end = $event['end_time'] !== null ? (string)$event['end_time'] : null;
        $needsLock = $courtId !== null && $courtId > 0 && $start && $end;
        if ($needsLock && !SlotLock::hold($db, $courtId)) {
            http_response_code(409);
            echo json_encode(['message' => 'This time is being booked. Try again.']);
            return;
        }
        try {
            $slotFree = true;
            if ($needsLock) {
                require_once __DIR__ . '/../Models/Booking.php';
                $slotFree = (new Booking())->isSlotAvailable($courtId, $start, $end, null);
            }
            $plan = TournamentPublish::plan((string)$event['status'], $courtId, $start, $end, $slotFree);
            if (!$plan['ok']) {
                http_response_code(422);
                echo json_encode(['message' => $plan['message']]);
                return;
            }
            $db->beginTransaction();
            $upd = $db->prepare("UPDATE tournaments SET status = 'published' WHERE id = ? AND status = 'draft'");
            $upd->execute([$id]);
            if (!$upd->rowCount()) {
                $db->rollBack();
                http_response_code(409);
                echo json_encode(['message' => 'Only a draft event can be published.']);
                return;
            }
            $blockId = null;
            if ($plan['block']) {
                $reason = function_exists('mb_substr') ? mb_substr((string)$event['title'], 0, 255) : substr((string)$event['title'], 0, 255);
                $block = $db->prepare("
                    INSERT INTO blocked_slots
                        (court_id, sub_court_id, start_time, end_time, reason, blocked_by, block_kind, repeat_annually, tournament_id)
                    VALUES (?, NULL, ?, ?, ?, ?, 'tournament', 0, ?)
                ");
                $block->execute([$courtId, $start, $end, $reason, $userId, $id]);
                $blockId = (int)$db->lastInsertId();
            }
            $db->commit();
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The event could not be published.']);
            return;
        } finally {
            if ($needsLock) {
                SlotLock::release($db, $courtId);
            }
        }

        http_response_code(200);
        echo json_encode([
            'status' => 'published',
            'block_id' => $blockId,
            'message' => $blockId ? 'Event published. The venue is closed for these times.' : 'Event published.',
        ]);
    }

    public function unpublish(int $id): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $stmt = $db->prepare('SELECT id, status FROM tournaments WHERE id = ?');
        $stmt->execute([$id]);
        $event = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$event) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return;
        }
        $org = $db->prepare('SELECT id FROM tournament_organizers WHERE tournament_id = ? AND user_id = ?');
        $org->execute([$id, $userId]);
        if (!$org->fetchColumn()) {
            http_response_code(403);
            echo json_encode(['message' => 'Only an organizer can unpublish this event']);
            return;
        }
        $plan = TournamentPublish::unpublish((string)$event['status']);
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        try {
            $db->beginTransaction();
            $upd = $db->prepare("UPDATE tournaments SET status = 'draft' WHERE id = ? AND status = 'published'");
            $upd->execute([$id]);
            if (!$upd->rowCount()) {
                $db->rollBack();
                http_response_code(409);
                echo json_encode(['message' => 'Only a published event can be unpublished.']);
                return;
            }
            $clear = $db->prepare('DELETE FROM blocked_slots WHERE tournament_id = ?');
            $clear->execute([$id]);
            $opened = $clear->rowCount() > 0;
            $db->commit();
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The event could not be unpublished.']);
            return;
        }

        http_response_code(200);
        echo json_encode([
            'status' => 'draft',
            'message' => $opened
                ? 'Event is a draft again. The venue is open for these times.'
                : 'Event is a draft again.',
        ]);
    }

    public function export(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $id, (int)$authUser['id'])) {
            return;
        }
        $stmt = $db->prepare("
            SELECT c.name AS category,
                   COALESCE(NULLIF(TRIM(u.name), ''), CONCAT('Player ', r.captain_user_id)) AS player,
                   r.state,
                   r.fee_amount AS fee,
                   r.check_in_code AS code,
                   r.checked_in_at
            FROM tournament_registrations r
            JOIN tournament_categories c ON c.id = r.category_id
            LEFT JOIN users u ON u.id = r.captain_user_id
            WHERE c.tournament_id = ?
            ORDER BY c.id, r.id
        ");
        $stmt->execute([$id]);
        header('Content-Type: text/csv; charset=UTF-8');
        header('Content-Disposition: attachment; filename="participants.csv"');
        echo TournamentParticipantExport::csv($stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function checkIn(int $tournamentId, int $categoryId, int $registrationId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id'])) {
            return;
        }
        if (!$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        $stmt = $db->prepare("
            SELECT r.id, r.state, r.checked_in_at, t.start_time, t.end_time
            FROM tournament_registrations r
            JOIN tournament_categories c ON c.id = r.category_id AND c.tournament_id = ?
            JOIN tournaments t ON t.id = c.tournament_id
            WHERE r.id = ? AND r.category_id = ?
        ");
        $stmt->execute([$tournamentId, $registrationId, $categoryId]);
        $entry = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$entry) {
            http_response_code(404);
            echo json_encode(['message' => 'Entry not found']);
            return;
        }
        $this->applyCheckIn($db, $entry);
    }

    public function checkInByCode(int $tournamentId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id'])) {
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $code = TournamentCheckIn::codeValue($input['code'] ?? null);
        if ($code === false) {
            http_response_code(422);
            echo json_encode(['message' => 'Enter the 8-character entry code.']);
            return;
        }
        $stmt = $db->prepare("
            SELECT r.id, r.state, r.checked_in_at, t.start_time, t.end_time
            FROM tournament_registrations r
            JOIN tournament_categories c ON c.id = r.category_id AND c.tournament_id = ?
            JOIN tournaments t ON t.id = c.tournament_id
            WHERE r.check_in_code = ?
        ");
        $stmt->execute([$tournamentId, $code]);
        $entry = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$entry) {
            http_response_code(404);
            echo json_encode(['message' => 'Entry not found']);
            return;
        }
        $this->applyCheckIn($db, $entry);
    }

    private function applyCheckIn(PDO $db, array $entry): void
    {
        $now = (new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata')))->format('Y-m-d H:i:s');
        $plan = TournamentCheckIn::decide(
            (string)$entry['state'],
            $entry['checked_in_at'] !== null ? (string)$entry['checked_in_at'] : null,
            $entry['start_time'] !== null ? (string)$entry['start_time'] : null,
            $entry['end_time'] !== null ? (string)$entry['end_time'] : null,
            $now
        );
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $upd = $db->prepare("UPDATE tournament_registrations SET checked_in_at = ? WHERE id = ? AND state = 'confirmed' AND checked_in_at IS NULL");
        $upd->execute([$now, (int)$entry['id']]);
        if (!$upd->rowCount()) {
            http_response_code(409);
            echo json_encode(['message' => 'This entry is already checked in.']);
            return;
        }
        echo json_encode(['message' => 'Checked in.', 'checked_in_at' => $now, 'state' => 'confirmed']);
    }

    public function announcements(int $id): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $id, (int)$authUser['id'])) {
            return;
        }
        $stmt = $db->prepare('SELECT id, title, body, created_at FROM tournament_announcements WHERE tournament_id = ? ORDER BY id DESC LIMIT 20');
        $stmt->execute([$id]);
        echo json_encode(['announcements' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    public function announce(int $id): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $event = $db->prepare('SELECT id, title, status, court_id FROM tournaments WHERE id = ?');
        $event->execute([$id]);
        $row = $event->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            http_response_code(404);
            echo json_encode(['message' => 'Event not found']);
            return;
        }
        $org = $db->prepare('SELECT id FROM tournament_organizers WHERE tournament_id = ? AND user_id = ?');
        $org->execute([$id, $userId]);
        if (!$org->fetchColumn()) {
            http_response_code(403);
            echo json_encode(['message' => 'Only an organizer can send an announcement']);
            return;
        }
        if ((string)$row['status'] === 'cancelled') {
            http_response_code(422);
            echo json_encode(['message' => 'This event is not sending announcements.']);
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $note = TournamentAnnouncement::fromInput($input);
        if (!$note['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $note['message']]);
            return;
        }
        $captains = $db->prepare("
            SELECT DISTINCT r.captain_user_id, r.state
            FROM tournament_registrations r
            JOIN tournament_categories c ON c.id = r.category_id
            WHERE c.tournament_id = ? AND r.captain_user_id > 0
        ");
        $captains->execute([$id]);
        $recipients = [];
        foreach ($captains->fetchAll(PDO::FETCH_ASSOC) as $captain) {
            if (TournamentAnnouncement::hears((string)$captain['state'])) {
                $recipients[(int)$captain['captain_user_id']] = true;
            }
        }
        $courtId = $row['court_id'] !== null && $row['court_id'] !== '' ? (int)$row['court_id'] : null;
        $noticeTitle = TournamentAnnouncement::noticeTitle((string)$row['title'], $note['title']);
        try {
            $db->beginTransaction();
            $ins = $db->prepare('INSERT INTO tournament_announcements (tournament_id, title, body, created_by) VALUES (?, ?, ?, ?)');
            $ins->execute([$id, $note['title'], $note['body'], $userId]);
            $announcementId = (int)$db->lastInsertId();
            $notify = $db->prepare('INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?, ?, ?, ?, ?)');
            foreach (array_keys($recipients) as $captainId) {
                $notify->execute([$captainId, 'tournament', $noticeTitle, $note['body'], $courtId]);
            }
            $db->commit();
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The announcement could not be sent.']);
            return;
        }
        http_response_code(201);
        echo json_encode([
            'id' => $announcementId,
            'recipients' => count($recipients),
            'message' => 'Announcement sent.',
        ]);
    }

    public function review(int $tournamentId, int $categoryId, int $registrationId, string $action): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id'])) {
            return;
        }
        if (!$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        $stmt = $db->prepare('SELECT id, state FROM tournament_registrations WHERE id = ? AND category_id = ?');
        $stmt->execute([$registrationId, $categoryId]);
        $entry = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$entry) {
            http_response_code(404);
            echo json_encode(['message' => 'Entry not found']);
            return;
        }
        $plan = TournamentApproval::decide((string)$entry['state'], $action);
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $upd = $db->prepare('UPDATE tournament_registrations SET state = ? WHERE id = ? AND state = ?');
        $upd->execute([$plan['state'], $registrationId, 'pending_approval']);
        if (!$upd->rowCount()) {
            http_response_code(409);
            echo json_encode(['message' => 'Only an entry waiting for approval can be reviewed.']);
            return;
        }
        echo json_encode(['message' => $plan['message'], 'state' => $plan['state']]);
    }

    public function matches(int $tournamentId, int $categoryId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id']) || !$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        $stmt = $db->prepare("
            SELECT m.id, m.round_label, m.status,
                   h.registration_id AS home_registration_id,
                   a.registration_id AS away_registration_id,
                   r.winner_registration_id, r.home_score, r.away_score
            FROM tournament_matches m
            LEFT JOIN tournament_match_participants h ON h.match_id = m.id AND h.side = 'home'
            LEFT JOIN tournament_match_participants a ON a.match_id = m.id AND a.side = 'away'
            LEFT JOIN tournament_results r ON r.match_id = m.id
            WHERE m.category_id = ?
            ORDER BY m.id
        ");
        $stmt->execute([$categoryId]);
        $plan = TournamentDraw::advance($this->matchBoard($db, $categoryId));
        $champion = ($plan['ok'] ?? false) ? ($plan['champion'] ?? null) : null;
        echo json_encode(['matches' => $stmt->fetchAll(PDO::FETCH_ASSOC), 'champion_registration_id' => $champion]);
    }

    public function addMatch(int $tournamentId, int $categoryId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id']) || !$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        if (!$this->eventCanSchedule($db, $tournamentId)) {
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $homeId = $this->wholeId($input['home_registration_id'] ?? null);
        $awayId = $this->wholeId($input['away_registration_id'] ?? null);
        if ($homeId === null || $awayId === null) {
            http_response_code(422);
            echo json_encode(['message' => 'A match needs two entries']);
            return;
        }
        $home = $this->categoryEntry($db, $categoryId, $homeId);
        $away = $this->categoryEntry($db, $categoryId, $awayId);
        if ($home === null || $away === null) {
            http_response_code(404);
            echo json_encode(['message' => 'Entry not found']);
            return;
        }
        $plan = TournamentDraw::pair([$home, $away]);
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $db->beginTransaction();
        $ins = $db->prepare("INSERT INTO tournament_matches (category_id, round_label, status) VALUES (?, 'Match', 'scheduled')");
        $ins->execute([$categoryId]);
        $matchId = (int)$db->lastInsertId();
        $side = $db->prepare('INSERT INTO tournament_match_participants (match_id, registration_id, side) VALUES (?, ?, ?)');
        $side->execute([$matchId, $homeId, 'home']);
        $side->execute([$matchId, $awayId, 'away']);
        $db->commit();
        echo json_encode(['id' => $matchId, 'status' => 'scheduled']);
    }

    public function buildBracket(int $tournamentId, int $categoryId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id']) || !$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        if (!$this->eventCanSchedule($db, $tournamentId)) {
            return;
        }
        $db->beginTransaction();
        try {
            $lock = $db->prepare('SELECT id FROM tournament_matches WHERE category_id = ? FOR UPDATE');
            $lock->execute([$categoryId]);
            $already = (bool)$lock->fetch();
            $entries = $db->prepare('SELECT id, state FROM tournament_registrations WHERE category_id = ? ORDER BY id');
            $entries->execute([$categoryId]);
            $plan = TournamentDraw::bracket($entries->fetchAll(PDO::FETCH_ASSOC), $already);
            if (!$plan['ok']) {
                $db->rollBack();
                http_response_code(422);
                echo json_encode(['message' => $plan['message']]);
                return;
            }
            $ins = $db->prepare('INSERT INTO tournament_matches (category_id, round_label, status) VALUES (?, ?, ?)');
            $side = $db->prepare('INSERT INTO tournament_match_participants (match_id, registration_id, side) VALUES (?, ?, ?)');
            foreach ($plan['pairs'] as $pair) {
                $ins->execute([$categoryId, 'Round 1', 'scheduled']);
                $matchId = (int)$db->lastInsertId();
                $side->execute([$matchId, $pair['home'], 'home']);
                $side->execute([$matchId, $pair['away'], 'away']);
            }
            if ($plan['bye'] !== null) {
                $ins->execute([$categoryId, 'Round 1', 'bye']);
                $matchId = (int)$db->lastInsertId();
                $side->execute([$matchId, $plan['bye'], 'home']);
            }
            $db->commit();
            echo json_encode(['pairs' => count($plan['pairs']), 'bye_registration_id' => $plan['bye']]);
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The bracket could not be saved.']);
        }
    }

    public function recordResult(int $tournamentId, int $categoryId, int $matchId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        if (!$this->organizerOf($db, $tournamentId, (int)$authUser['id']) || !$this->categoryInEvent($db, $tournamentId, $categoryId)) {
            return;
        }
        if (!$this->eventCanSchedule($db, $tournamentId)) {
            return;
        }
        $match = $db->prepare('SELECT id, status FROM tournament_matches WHERE id = ? AND category_id = ?');
        $match->execute([$matchId, $categoryId]);
        $row = $match->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            http_response_code(404);
            echo json_encode(['message' => 'Match not found']);
            return;
        }
        $sides = $db->prepare('SELECT registration_id, side FROM tournament_match_participants WHERE match_id = ?');
        $sides->execute([$matchId]);
        $homeId = 0;
        $awayId = 0;
        foreach ($sides->fetchAll(PDO::FETCH_ASSOC) as $side) {
            if ($side['side'] === 'home') {
                $homeId = (int)$side['registration_id'];
            }
            if ($side['side'] === 'away') {
                $awayId = (int)$side['registration_id'];
            }
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $homeScore = $this->wholeId($input['home_score'] ?? null);
        $awayScore = $this->wholeId($input['away_score'] ?? null);
        $winnerId = $this->wholeId($input['winner_registration_id'] ?? null);
        if ($homeScore === null || $awayScore === null || $winnerId === null) {
            http_response_code(422);
            echo json_encode(['message' => 'A winner needs a higher score']);
            return;
        }
        $existing = $db->prepare('SELECT id FROM tournament_results WHERE match_id = ?');
        $existing->execute([$matchId]);
        $plan = TournamentDraw::score($homeId, $awayId, $winnerId, $homeScore, $awayScore, (bool)$existing->fetchColumn());
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        try {
            $db->beginTransaction();
            $ins = $db->prepare('INSERT INTO tournament_results (match_id, winner_registration_id, home_score, away_score) VALUES (?, ?, ?, ?)');
            $ins->execute([$matchId, $winnerId, $homeScore, $awayScore]);
            $upd = $db->prepare("UPDATE tournament_matches SET status = 'completed' WHERE id = ? AND status = 'scheduled'");
            $upd->execute([$matchId]);
            if (!$upd->rowCount()) {
                $db->rollBack();
                http_response_code(409);
                echo json_encode(['message' => 'This match already has a result']);
                return;
            }
            $lock = $db->prepare('SELECT id FROM tournament_matches WHERE category_id = ? FOR UPDATE');
            $lock->execute([$categoryId]);
            $lock->fetchAll();
            $next = $this->placeNextRound($db, $categoryId);
            if (isset($next['refused'])) {
                $db->rollBack();
                http_response_code(409);
                echo json_encode(['message' => $next['refused']]);
                return;
            }
            $db->commit();
        } catch (PDOException $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(409);
            echo json_encode(['message' => 'This match already has a result']);
            return;
        }
        echo json_encode([
            'status' => 'completed',
            'winner_registration_id' => $winnerId,
            'next_round' => $next['next_round'],
            'champion_registration_id' => $next['champion_registration_id'],
        ]);
    }

    /** @return array{next_round:?string,champion_registration_id:?int} */
    private function placeNextRound(PDO $db, int $categoryId): array
    {
        $plan = TournamentDraw::advance($this->matchBoard($db, $categoryId));
        $empty = ['next_round' => null, 'champion_registration_id' => null];
        if (!$plan['ok']) {
            if (($plan['message'] ?? '') === 'A player can advance only once') {
                return ['next_round' => null, 'champion_registration_id' => null, 'refused' => $plan['message']];
            }
            return $empty;
        }
        if ($plan['pairs'] === [] && $plan['bye'] === null) {
            return ['next_round' => null, 'champion_registration_id' => $plan['champion']];
        }
        $ins = $db->prepare('INSERT INTO tournament_matches (category_id, round_label, status) VALUES (?, ?, ?)');
        $side = $db->prepare('INSERT INTO tournament_match_participants (match_id, registration_id, side) VALUES (?, ?, ?)');
        foreach ($plan['pairs'] as $pair) {
            $ins->execute([$categoryId, $plan['round'], 'scheduled']);
            $matchId = (int)$db->lastInsertId();
            $side->execute([$matchId, $pair['home'], 'home']);
            $side->execute([$matchId, $pair['away'], 'away']);
        }
        if ($plan['bye'] !== null) {
            $ins->execute([$categoryId, $plan['round'], 'bye']);
            $matchId = (int)$db->lastInsertId();
            $side->execute([$matchId, $plan['bye'], 'home']);
        }
        return ['next_round' => $plan['round'], 'champion_registration_id' => null];
    }

    /** @return list<array{round:string,status:string,home:int,winner:int}> */
    private function matchBoard(PDO $db, int $categoryId): array
    {
        $stmt = $db->prepare("
            SELECT m.round_label, m.status, h.registration_id AS home_registration_id, r.winner_registration_id
            FROM tournament_matches m
            LEFT JOIN tournament_match_participants h ON h.match_id = m.id AND h.side = 'home'
            LEFT JOIN tournament_results r ON r.match_id = m.id
            WHERE m.category_id = ?
            ORDER BY m.id
        ");
        $stmt->execute([$categoryId]);
        $rows = [];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $rows[] = [
                'round' => (string)$row['round_label'],
                'status' => (string)$row['status'],
                'home' => $row['home_registration_id'] !== null ? (int)$row['home_registration_id'] : 0,
                'winner' => $row['winner_registration_id'] !== null ? (int)$row['winner_registration_id'] : 0,
            ];
        }
        return $rows;
    }

    private function eventCanSchedule(PDO $db, int $tournamentId): bool
    {
        $stmt = $db->prepare('SELECT status FROM tournaments WHERE id = ?');
        $stmt->execute([$tournamentId]);
        if ((string)$stmt->fetchColumn() === 'cancelled') {
            http_response_code(422);
            echo json_encode(['message' => 'This event is not scheduling matches.']);
            return false;
        }
        return true;
    }

    /** @return array{id:int,state:string}|null */
    private function categoryEntry(PDO $db, int $categoryId, int $registrationId): ?array
    {
        $stmt = $db->prepare('SELECT id, state FROM tournament_registrations WHERE id = ? AND category_id = ?');
        $stmt->execute([$registrationId, $categoryId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            return null;
        }
        return ['id' => (int)$row['id'], 'state' => (string)$row['state']];
    }

    private function wholeId(mixed $value): ?int
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
