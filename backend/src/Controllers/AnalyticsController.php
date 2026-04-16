<?php

class AnalyticsController
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    // GET /analytics?owner_id=X&period=30  (period in days, default 30)
    public function index(): void
    {
        $owner_id = (int)($_GET['owner_id'] ?? 0);
        $period   = max(7, min(365, (int)($_GET['period'] ?? 30)));
        if (!$owner_id) { http_response_code(400); echo json_encode(['message' => 'owner_id required']); return; }

        $since = date('Y-m-d', strtotime("-{$period} days"));

        // ── Revenue by day ─────────────────────────────────────────────────────
        $revStmt = $this->db->prepare("
            SELECT DATE(b.start_time) AS day,
                   SUM(b.total_price) AS revenue,
                   COUNT(*)           AS bookings
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND DATE(b.start_time) >= ?
            GROUP BY DATE(b.start_time)
            ORDER BY day
        ");
        $revStmt->execute([$owner_id, $since]);
        $revenueByDay = $revStmt->fetchAll(PDO::FETCH_ASSOC);

        // ── Occupancy heatmap (day-of-week × hour) ─────────────────────────────
        $heatStmt = $this->db->prepare("
            SELECT DAYOFWEEK(b.start_time) - 1 AS dow,   -- 0=Sun…6=Sat
                   HOUR(b.start_time)           AS hour,
                   COUNT(*)                     AS count
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND DATE(b.start_time) >= ?
            GROUP BY dow, hour
        ");
        $heatStmt->execute([$owner_id, $since]);
        $heatRaw = $heatStmt->fetchAll(PDO::FETCH_ASSOC);

        // Build 7×24 grid
        $heatmap = [];
        foreach ($heatRaw as $row) {
            $heatmap[(int)$row['dow']][(int)$row['hour']] = (int)$row['count'];
        }

        // ── Top courts ─────────────────────────────────────────────────────────
        $topStmt = $this->db->prepare("
            SELECT c.id, c.name, c.type,
                   COUNT(b.id)        AS booking_count,
                   SUM(b.total_price) AS revenue
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND DATE(b.start_time) >= ?
            GROUP BY c.id
            ORDER BY revenue DESC
            LIMIT 5
        ");
        $topStmt->execute([$owner_id, $since]);
        $topCourts = $topStmt->fetchAll(PDO::FETCH_ASSOC);

        // ── Summary ────────────────────────────────────────────────────────────
        $sumStmt = $this->db->prepare("
            SELECT
                COUNT(*)           AS total_bookings,
                SUM(b.total_price) AS total_revenue,
                COUNT(DISTINCT b.user_id) AS unique_players,
                AVG(b.total_price) AS avg_booking_value
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND DATE(b.start_time) >= ?
        ");
        $sumStmt->execute([$owner_id, $since]);
        $summary = $sumStmt->fetch(PDO::FETCH_ASSOC);

        // ── Cancellation rate ──────────────────────────────────────────────────
        $cancelStmt = $this->db->prepare("
            SELECT
                SUM(CASE WHEN b.status='cancelled' THEN 1 ELSE 0 END) AS cancelled,
                COUNT(*) AS total
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND DATE(b.start_time) >= ?
        ");
        $cancelStmt->execute([$owner_id, $since]);
        $cancel = $cancelStmt->fetch(PDO::FETCH_ASSOC);
        $cancelRate = $cancel['total'] > 0
            ? round(100 * $cancel['cancelled'] / $cancel['total'], 1)
            : 0;

        // ── Peak hours (top 5) ─────────────────────────────────────────────────
        $peakStmt = $this->db->prepare("
            SELECT HOUR(b.start_time) AS hour, COUNT(*) AS count
            FROM bookings b
            JOIN courts c ON c.id = b.court_id
            WHERE c.owner_id = ? AND b.status = 'confirmed' AND DATE(b.start_time) >= ?
            GROUP BY hour ORDER BY count DESC LIMIT 5
        ");
        $peakStmt->execute([$owner_id, $since]);
        $peakHours = $peakStmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            'period'        => $period,
            'since'         => $since,
            'summary'       => $summary,
            'cancel_rate'   => $cancelRate,
            'revenue_by_day'=> $revenueByDay,
            'heatmap'       => $heatmap,
            'top_courts'    => $topCourts,
            'peak_hours'    => $peakHours,
        ]);
    }
}
