<?php
require_once __DIR__ . '/../RefundService.php';

final class RefundController {
    public function admin(array $segments): void {
        $actor=Auth::requireAdmin(); $db=Database::getConnection();
        if ($_SERVER['REQUEST_METHOD']==='GET') {
            $rows=$db->query('SELECT r.id,r.booking_id,r.reason,r.amount_paise,r.status,r.provider_status,r.error_code,r.refund_id,r.bank_reference,r.created_at,r.attempts,c.name court_name FROM refund_requests r LEFT JOIN bookings b ON b.id=r.booking_id LEFT JOIN courts c ON c.id=b.court_id ORDER BY r.id DESC LIMIT 100')->fetchAll(PDO::FETCH_ASSOC);
            $legacy=$db->query('SELECT r.*,c.name court_name FROM booking_refunds r JOIN bookings b ON b.id=r.booking_id JOIN courts c ON c.id=b.court_id WHERE r.refund_request_id IS NULL ORDER BY r.id DESC LIMIT 100')->fetchAll(PDO::FETCH_ASSOC);
            foreach($legacy as &$r) $r['legacy']=true;
            echo json_encode(['records'=>array_merge($rows,$legacy)]); return;
        }
        $action=$segments[3] ?? '';
        if ($_SERVER['REQUEST_METHOD']!=='POST' || !ctype_digit($segments[2] ?? '') || !in_array($action,['submit','sync'],true)) { http_response_code(405); return; }
        $s=$db->prepare('SELECT id FROM refund_requests WHERE id=?'); $s->execute([(int)$segments[2]]);
        if (!$s->fetchColumn()) { http_response_code(404); echo json_encode(['message'=>'Refund not found']); return; }
        $result=(new RefundService($db))->process((int)$segments[2],$action==='submit',$action==='sync',(int)$actor['id']);
        echo json_encode(['refund'=>RefundService::publicStatus($result)]);
    }
    public function mine(): void {
        $actor=Auth::require(); $db=Database::getConnection();
        $s=$db->prepare('SELECT r.* FROM refund_requests r JOIN payments p ON p.id=r.payment_id WHERE p.user_id=? ORDER BY r.id DESC LIMIT 100'); $s->execute([$actor['id']]);
        echo json_encode(['records'=>array_map([RefundService::class,'publicStatus'],$s->fetchAll(PDO::FETCH_ASSOC))]);
    }
    public function webhook(): void {
        require_once __DIR__ . '/../../config/cashfree.php';
        $raw=file_get_contents('php://input');
        if (strlen($raw)>1048576 || !RefundWebhookSignature::valid($raw,$_SERVER['HTTP_X_WEBHOOK_TIMESTAMP'] ?? '',$_SERVER['HTTP_X_WEBHOOK_SIGNATURE'] ?? '',CASHFREE_SECRET_KEY)) { http_response_code(401); echo json_encode(['message'=>'Invalid signature']); return; }
        $event=json_decode($raw,true); $data=$event['data']['refund'] ?? $event['data'] ?? [];
        if (!is_array($data) || !is_string($data['refund_id'] ?? '') || strlen($data['refund_id'] ?? '')>40) { http_response_code(422); return; }
        $id=$data['refund_id'] ?? ''; $db=Database::getConnection();
        $fingerprint=hash('sha256',$raw);
        $seen=$db->prepare('SELECT fingerprint FROM refund_webhook_events WHERE fingerprint=?'); $seen->execute([$fingerprint]);
        if ($seen->fetchColumn()) { echo json_encode(['received'=>true]); return; }
        $s=$db->prepare('SELECT id,status FROM refund_requests WHERE refund_id=?'); $s->execute([$id]); $row=$s->fetch(PDO::FETCH_ASSOC);
        // Never initiate refunds from a webhook; fetch authoritative provider state.
        if ($row) {
            $result=(new RefundService($db))->process((int)$row['id'],false,true);
            if (in_array($result['error_code'],['lookup_unavailable','worker_error'],true)) { http_response_code(503); echo json_encode(['message'=>'Retry later']); return; }
        }
        if ($row) {
            try { $db->prepare('INSERT INTO refund_webhook_events (fingerprint,processed_at) VALUES (?,?)')->execute([$fingerprint,gmdate('Y-m-d H:i:s')]); }
            catch(PDOException $e) { if ($e->getCode() !== '23000') throw $e; }
        }
        echo json_encode(['received'=>true]);
    }
}
