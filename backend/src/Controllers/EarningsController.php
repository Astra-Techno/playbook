<?php

require_once __DIR__ . '/../../config/database.php';

class EarningsController {

    // GET /earnings?owner_id=X
    public function index(): void {
        $owner_id = (int)($_GET['owner_id'] ?? 0);
        if (!$owner_id) {
            http_response_code(400);
            echo json_encode(['message' => 'owner_id required']);
            return;
        }

        $db = Database::getConnection();

        // ── Aggregate helpers ──────────────────────────────────────────────────
        $weekStart  = date('Y-m-d', strtotime('monday this week'));
        $monthStart = date('Y-m-01');

        $totalEarned  = $this->sumEarnings($db, $owner_id, null, null);
        $thisWeek     = $this->sumEarnings($db, $owner_id, $weekStart, null);
        $thisMonth    = $this->sumEarnings($db, $owner_id, $monthStart, null);

        // Total paid out
        $stmt = $db->prepare("SELECT COALESCE(SUM(amount),0) FROM payouts WHERE owner_id = ?");
        $stmt->execute([$owner_id]);
        $totalPaidOut = (float)$stmt->fetchColumn();

        $pending = max(0, $totalEarned - $totalPaidOut);

        // ── Recent transactions (last 30) ──────────────────────────────────────
        $transactions = $this->getTransactions($db, $owner_id, 30);

        // ── Payout history ────────────────────────────────────────────────────
        $pStmt = $db->prepare(
            "SELECT id, amount, note, paid_at FROM payouts WHERE owner_id = ? ORDER BY paid_at DESC"
        );
        $pStmt->execute([$owner_id]);
        $payouts = $pStmt->fetchAll(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode([
            'summary' => [
                'total_earned'  => $totalEarned,
                'this_week'     => $thisWeek,
                'this_month'    => $thisMonth,
                'total_paid_out'=> $totalPaidOut,
                'pending_payout'=> $pending,
            ],
            'transactions' => $transactions,
            'payouts'      => $payouts,
        ]);
    }

    // POST /payouts  { owner_id, amount, note }  — admin records a manual payout
    public function createPayout(): void {
        $data     = json_decode(file_get_contents('php://input'));
        $owner_id = (int)($data->owner_id ?? 0);
        $amount   = round(floatval($data->amount ?? 0), 2);
        $note     = trim($data->note ?? '');

        if (!$owner_id || $amount <= 0) {
            http_response_code(400);
            echo json_encode(['message' => 'owner_id and amount are required']);
            return;
        }

        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "INSERT INTO payouts (owner_id, amount, note) VALUES (?, ?, ?)"
        );
        $stmt->execute([$owner_id, $amount, $note ?: null]);

        http_response_code(201);
        echo json_encode(['message' => 'Payout recorded', 'id' => $db->lastInsertId()]);
    }

    // GET /earnings/ledger?owner_id=X[&type=booking|subscription|payout][&from=YYYY-MM-DD][&to=YYYY-MM-DD]
    public function ledger(): void {
        $owner_id = (int)($_GET['owner_id'] ?? 0);
        if (!$owner_id) {
            http_response_code(400);
            echo json_encode(['message' => 'owner_id required']);
            return;
        }

        $type = $_GET['type'] ?? 'all';   // all | booking | subscription | payout
        $from = $_GET['from'] ?? null;
        $to   = $_GET['to']   ?? null;

        $db = Database::getConnection();

        // ── Credits: bookings ─────────────────────────────────────────────────
        $credits = [];

        if ($type === 'all' || $type === 'booking') {
            $extra = "AND p.status = 'paid'";
            $params = [$owner_id];
            if ($from) { $extra .= " AND p.created_at >= ?"; $params[] = $from; }
            if ($to)   { $extra .= " AND p.created_at <= ?"; $params[] = $to . ' 23:59:59'; }

            $sql = "
                SELECT p.id, 'booking' AS kind, p.amount, p.created_at AS dated,
                       c.name AS label, u.name AS party
                FROM payments p
                JOIN bookings b ON p.reference_id = b.id AND p.type = 'booking'
                JOIN courts c ON b.court_id = c.id
                JOIN users u ON b.user_id = u.id
                WHERE c.owner_id = ? $extra
            ";
            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            $credits = array_merge($credits, $stmt->fetchAll(PDO::FETCH_ASSOC));
        }

        if ($type === 'all' || $type === 'subscription') {
            $extra = "AND p.status = 'paid'";
            $params = [$owner_id];
            if ($from) { $extra .= " AND p.created_at >= ?"; $params[] = $from; }
            if ($to)   { $extra .= " AND p.created_at <= ?"; $params[] = $to . ' 23:59:59'; }

            $sql = "
                SELECT p.id, 'subscription' AS kind, p.amount, p.created_at AS dated,
                       c.name AS label, u.name AS party
                FROM payments p
                JOIN user_subscriptions s ON p.reference_id = s.id AND p.type = 'subscription'
                JOIN courts c ON s.court_id = c.id
                JOIN users u ON s.user_id = u.id
                WHERE c.owner_id = ? $extra
            ";
            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            $credits = array_merge($credits, $stmt->fetchAll(PDO::FETCH_ASSOC));
        }

        // ── Debits: payouts ────────────────────────────────────────────────────
        $debits = [];
        if ($type === 'all' || $type === 'payout') {
            $extra = '';
            $params = [$owner_id];
            if ($from) { $extra .= " AND paid_at >= ?"; $params[] = $from; }
            if ($to)   { $extra .= " AND paid_at <= ?"; $params[] = $to . ' 23:59:59'; }

            $stmt = $db->prepare(
                "SELECT id, 'payout' AS kind, amount, paid_at AS dated,
                        COALESCE(note,'Payout') AS label, 'Platform' AS party
                 FROM payouts WHERE owner_id = ? $extra"
            );
            $stmt->execute($params);
            $debits = $stmt->fetchAll(PDO::FETCH_ASSOC);
        }

        // ── Merge, sort by date desc, add running balance ──────────────────────
        $all = [];
        foreach ($credits as $r) {
            $all[] = ['id' => $r['id'], 'kind' => $r['kind'], 'amount' => (float)$r['amount'],
                      'dated' => $r['dated'], 'label' => $r['label'], 'party' => $r['party'], 'direction' => 'credit'];
        }
        foreach ($debits as $r) {
            $all[] = ['id' => $r['id'], 'kind' => 'payout', 'amount' => (float)$r['amount'],
                      'dated' => $r['dated'], 'label' => $r['label'], 'party' => $r['party'], 'direction' => 'debit'];
        }

        usort($all, fn($a, $b) => strcmp($b['dated'], $a['dated']));

        // Running balance (from oldest to newest, then reverse for display)
        $sorted_asc = array_reverse($all);
        $balance = 0;
        foreach ($sorted_asc as &$row) {
            $balance += $row['direction'] === 'credit' ? $row['amount'] : -$row['amount'];
            $row['balance'] = round($balance, 2);
        }
        unset($row);
        $final = array_reverse($sorted_asc);

        // Totals
        $totalCredits = array_sum(array_column(array_filter($all, fn($r) => $r['direction'] === 'credit'), 'amount'));
        $totalDebits  = array_sum(array_column(array_filter($all, fn($r) => $r['direction'] === 'debit'),  'amount'));

        http_response_code(200);
        echo json_encode([
            'totals' => [
                'credits' => round($totalCredits, 2),
                'debits'  => round($totalDebits, 2),
                'balance' => round($totalCredits - $totalDebits, 2),
            ],
            'entries' => $final,
        ]);
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private function sumEarnings($db, int $owner_id, ?string $from, ?string $to): float {
        $where = "c.owner_id = ? AND p.status = 'paid'";
        $params = [$owner_id, $owner_id];
        if ($from) { $where .= " AND p.created_at >= ?"; $params[] = $from; $params[] = $from; }
        if ($to)   { $where .= " AND p.created_at <= ?"; $params[] = $to;   $params[] = $to;   }

        // Rebuild params for two UNION arms
        $p1 = [$owner_id];
        $p2 = [$owner_id];
        $extra = '';
        if ($from) { $extra .= " AND p.created_at >= ?"; $p1[] = $from; $p2[] = $from; }
        if ($to)   { $extra .= " AND p.created_at <= ?"; $p1[] = $to;   $p2[] = $to;   }

        $sql = "
            SELECT COALESCE(SUM(amt),0) FROM (
                SELECT p.amount AS amt
                FROM payments p
                JOIN bookings b ON p.reference_id = b.id AND p.type = 'booking'
                JOIN courts c ON b.court_id = c.id
                WHERE c.owner_id = ? AND p.status = 'paid' $extra
                UNION ALL
                SELECT p.amount AS amt
                FROM payments p
                JOIN user_subscriptions s ON p.reference_id = s.id AND p.type = 'subscription'
                JOIN courts c ON s.court_id = c.id
                WHERE c.owner_id = ? AND p.status = 'paid' $extra
            ) t
        ";
        $stmt = $db->prepare($sql);
        $stmt->execute(array_merge($p1, $p2));
        return (float)$stmt->fetchColumn();
    }

    private function getTransactions($db, int $owner_id, int $limit): array {
        $sql = "
            SELECT p.id, p.amount, p.type, p.created_at,
                   c.name AS court_name, u.name AS customer_name,
                   b.start_time AS slot_time
            FROM payments p
            JOIN bookings b ON p.reference_id = b.id AND p.type = 'booking'
            JOIN courts c ON b.court_id = c.id
            JOIN users u ON b.user_id = u.id
            WHERE c.owner_id = ? AND p.status = 'paid'

            UNION ALL

            SELECT p.id, p.amount, p.type, p.created_at,
                   c.name AS court_name, u.name AS customer_name,
                   s.start_date AS slot_time
            FROM payments p
            JOIN user_subscriptions s ON p.reference_id = s.id AND p.type = 'subscription'
            JOIN courts c ON s.court_id = c.id
            JOIN users u ON s.user_id = u.id
            WHERE c.owner_id = ? AND p.status = 'paid'

            ORDER BY created_at DESC
            LIMIT ?
        ";
        $stmt = $db->prepare($sql);
        $stmt->execute([$owner_id, $owner_id, $limit]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
