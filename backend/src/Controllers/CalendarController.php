<?php

class CalendarController
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    // GET /courts/:id/calendar?date=YYYY-MM-DD&view=day|week
    public function day(int $courtId): void
    {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];

        // Verify: owner or staff
        $ok = $this->db->prepare("SELECT id FROM courts WHERE id=? AND owner_id=?");
        $ok->execute([$courtId, $userId]);
        if (!$ok->fetch()) {
            $ok2 = $this->db->prepare("SELECT id FROM court_staff WHERE court_id=? AND user_id=?");
            $ok2->execute([$courtId, $userId]);
            if (!$ok2->fetch()) {
                http_response_code(403);
                echo json_encode(['message' => 'Forbidden']);
                return;
            }
        }

        // Court info
        $cStmt = $this->db->prepare(
            "SELECT id, name, open_time, close_time FROM courts WHERE id=? LIMIT 1"
        );
        $cStmt->execute([$courtId]);
        $court = $cStmt->fetch(PDO::FETCH_ASSOC);
        if (!$court) {
            http_response_code(404);
            echo json_encode(['message' => 'Court not found']);
            return;
        }
        $court['open_time']  = $court['open_time']  ?: '06:00:00';
        $court['close_time'] = $court['close_time'] ?: '22:00:00';

        // Sub-courts
        $scStmt = $this->db->prepare(
            "SELECT id, name, booking_mode, capacity
             FROM sub_courts WHERE court_id=? ORDER BY sort_order, id"
        );
        $scStmt->execute([$courtId]);
        $subCourts = $scStmt->fetchAll(PDO::FETCH_ASSOC);

        $view = $_GET['view'] ?? 'day';
        $date = isset($_GET['date']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $_GET['date'])
            ? $_GET['date']
            : date('Y-m-d');

        if ($view === 'week') {
            $this->weekView($courtId, $date, $court, $subCourts);
            return;
        }

        // ── Day view ───────────────────────────────────────────
        $bStmt = $this->db->prepare("
            SELECT b.id, b.sub_court_id, b.start_time, b.end_time, b.status,
                   b.guest_name, b.guest_phone, b.notes, b.total_price,
                   u.name AS user_name, u.phone AS user_phone
            FROM bookings b
            LEFT JOIN users u ON u.id = b.user_id
            WHERE b.court_id = ? AND DATE(b.start_time) = ?
            ORDER BY b.start_time
        ");
        $bStmt->execute([$courtId, $date]);

        $blStmt = $this->db->prepare("
            SELECT id, sub_court_id, start_time, end_time, reason, block_kind
            FROM blocked_slots
            WHERE court_id = ?
              AND (
                DATE(start_time) = ?
                OR (repeat_annually = 1
                    AND DATE_FORMAT(start_time, '%m-%d') = DATE_FORMAT(?, '%m-%d'))
              )
            ORDER BY start_time
        ");
        $blStmt->execute([$courtId, $date, $date]);

        echo json_encode([
            'court'         => $court,
            'sub_courts'    => $subCourts,
            'view'          => 'day',
            'date'          => $date,
            'bookings'      => $bStmt->fetchAll(PDO::FETCH_ASSOC),
            'blocked_slots' => $blStmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }

    private function weekView(int $courtId, string $date, array $court, array $subCourts): void
    {
        $ts  = strtotime($date);
        $dow = (int)date('N', $ts);            // 1=Mon … 7=Sun
        $mon = date('Y-m-d', strtotime('-' . ($dow - 1) . ' days', $ts));
        $sun = date('Y-m-d', strtotime('+6 days', strtotime($mon)));

        $dates = [];
        for ($i = 0; $i < 7; $i++) {
            $dates[] = date('Y-m-d', strtotime("+{$i} days", strtotime($mon)));
        }

        $bStmt = $this->db->prepare("
            SELECT b.id, b.sub_court_id, b.start_time, b.end_time, b.status,
                   b.guest_name, b.guest_phone, b.notes, b.total_price,
                   u.name AS user_name, u.phone AS user_phone
            FROM bookings b
            LEFT JOIN users u ON u.id = b.user_id
            WHERE b.court_id = ? AND DATE(b.start_time) BETWEEN ? AND ?
            ORDER BY b.start_time
        ");
        $bStmt->execute([$courtId, $mon, $sun]);

        $blStmt = $this->db->prepare("
            SELECT id, sub_court_id, start_time, end_time, reason, block_kind
            FROM blocked_slots
            WHERE court_id = ?
              AND (DATE(start_time) BETWEEN ? AND ?
                   OR (repeat_annually = 1
                       AND DATE_FORMAT(start_time, '%m-%d')
                           BETWEEN DATE_FORMAT(?, '%m-%d') AND DATE_FORMAT(?, '%m-%d')))
            ORDER BY start_time
        ");
        $blStmt->execute([$courtId, $mon, $sun, $mon, $sun]);

        echo json_encode([
            'court'         => $court,
            'sub_courts'    => $subCourts,
            'view'          => 'week',
            'date'          => $date,
            'dates'         => $dates,
            'bookings'      => $bStmt->fetchAll(PDO::FETCH_ASSOC),
            'blocked_slots' => $blStmt->fetchAll(PDO::FETCH_ASSOC),
        ]);
    }
}
