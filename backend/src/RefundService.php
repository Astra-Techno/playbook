<?php
require_once __DIR__ . '/CommerceSettings.php';
require_once __DIR__ . '/CashfreeRefundGateway.php';

/** Durable refund outbox. No network calls are made while reserving money. */
final class RefundService {
    public function __construct(private PDO $db, private ?RefundGateway $gateway = null) {}
    private function lock(): string { return $this->db->getAttribute(PDO::ATTR_DRIVER_NAME) === 'mysql' ? ' FOR UPDATE' : ''; }
    private function row(int $id): array {
        $s = $this->db->prepare('SELECT r.*, p.cf_order_id, p.cf_payment_id FROM refund_requests r JOIN payments p ON p.id=r.payment_id WHERE r.id=?');
        $s->execute([$id]); return $s->fetch(PDO::FETCH_ASSOC) ?: throw new RuntimeException('Refund not found');
    }
    public function enqueue(int $paymentId, ?int $bookingId, string $key, string $reason, int $venue, int $fee, int $actor): array {
        if (!$this->db->inTransaction()) throw new LogicException('Refund reservation requires a transaction');
        $s = $this->db->prepare('SELECT * FROM payments WHERE id=?' . $this->lock()); $s->execute([$paymentId]);
        $p = $s->fetch(PDO::FETCH_ASSOC);
        if (!$p || !in_array($p['status'], ['paid', 'refund_pending'], true)) throw new RuntimeException('Payment is not verified');
        $s = $this->db->prepare('SELECT * FROM refund_requests WHERE request_key=?'); $s->execute([$key]);
        if ($existing = $s->fetch(PDO::FETCH_ASSOC)) {
            if ((int)$existing['payment_id'] !== $paymentId || (int)$existing['amount_paise'] !== $venue + $fee || (int)$existing['venue_paise'] !== $venue || (int)$existing['fee_paise'] !== $fee) throw new LogicException('Refund reservation mismatch');
            return $existing;
        }
        $s = $this->db->prepare('SELECT COALESCE(SUM(amount_paise),0) total, COALESCE(SUM(venue_paise),0) venue, COALESCE(SUM(fee_paise),0) fee, COALESCE(SUM(vendor_paise),0) vendor FROM refund_requests WHERE payment_id=?');
        $s->execute([$paymentId]); $used = $s->fetch(PDO::FETCH_ASSOC);
        $snapshot = json_decode($p['commerce_snapshot'] ?? 'null', true);
        $price = $snapshot['price'] ?? null;
        if ($venue < 0 || $fee < 0 || $venue + $fee <= 0 || $venue + $fee + $used['total'] > (int)round($p['amount'] * 100)
            || !$price || $venue + $used['venue'] > $price['venue']['total'] || $fee + $used['fee'] > $price['fee']['total']) throw new LogicException('Refund exceeds original payment components');
        $meta = $snapshot['gateway'] ?? null;
        $policy = CommerceSettings::load($this->db);
        $state = $policy['refund.automation_enabled'] && $venue + $fee <= (int)round($policy['refund.auto_limit_inr'] * 100) ? 'queued' : 'manual_review';
        $error = $state === 'manual_review' ? 'approval_required' : null;
        $refundId = 'kc' . substr(hash('sha256', $key), 0, 36);
        $hex = bin2hex(random_bytes(16));
        $uuid = substr($hex,0,8).'-'.substr($hex,8,4).'-4'.substr($hex,13,3).'-a'.substr($hex,17,3).'-'.substr($hex,20,12);
        $body = ['refund_id' => $refundId, 'refund_amount' => ($venue + $fee) / 100, 'refund_note' => 'KoCourt ' . $reason, 'refund_speed' => 'STANDARD'];
        $vendor = 0;
        if (!$meta || !in_array($meta['mode'] ?? '', ['demo', 'cashfree'], true) || !in_array($meta['environment'] ?? '', ['sandbox', 'production'], true)) {
            $state = 'manual_review'; $error = 'missing_original_gateway'; $body = null;
        } elseif ($meta['mode'] === 'demo') { $state = 'simulated'; $error = null; }
        elseif (empty($p['cf_payment_id'])) { $state = 'manual_review'; $error = 'missing_verified_payment'; $body = null; }
        elseif (count($meta['splits'] ?? []) > 1) { $state = 'manual_review'; $error = 'unsupported_original_split'; $body = null; }
        elseif (!empty($meta['splits'])) {
            $split = $meta['splits'][0]; $original = (int)round($split['amount'] * 100);
            $vendor = $venue + $used['venue'] === (int)$price['venue']['total'] ? $original - (int)$used['vendor'] : (int)floor($original * $venue / max(1, $price['venue']['total']));
            $vendor = max(0, min($vendor, $original - (int)$used['vendor']));
            $body['refund_splits'] = [['vendor_id' => $split['vendor_id'], 'amount' => $vendor / 100]];
        }
        $now = gmdate('Y-m-d H:i:s');
        $s = $this->db->prepare('INSERT INTO refund_requests (request_key,payment_id,booking_id,reason,amount_paise,venue_paise,fee_paise,vendor_paise,refund_id,idempotency_key,request_body,environment,status,error_code,requested_by,created_at,updated_at,next_attempt_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
        $s->execute([$key,$paymentId,$bookingId,$reason,$venue+$fee,$venue,$fee,$vendor,$refundId,$uuid,$body ? json_encode($body, JSON_THROW_ON_ERROR) : null,$meta['environment'] ?? 'unknown',$state,$error,$actor,$now,$now,$now]);
        $id = (int)$this->db->lastInsertId(); $this->event($id, $state, 'reservation', $error);
        return $this->row($id);
    }
    private function event(int $id, string $state, string $source, ?string $detail): void {
        $this->db->prepare('INSERT INTO refund_events (refund_request_id,status,source,detail,created_at) VALUES (?,?,?,?,?)')->execute([$id,$state,$source,$detail,gmdate('Y-m-d H:i:s')]);
    }
    public static function publicStatus(array $r): array {
        return ['id'=>(int)$r['id'],'status'=>$r['status'],'amount'=>$r['amount_paise']/100,'reference'=>$r['refund_id'],'bank_reference'=>$r['bank_reference'] ?? null];
    }
    /** A lease serializes workers; each retry uses the same persisted ID, key and body. */
    public function process(int $id, bool $approved = false, bool $reconcileOnly = false, int $actor = 0): array {
        if ($this->db->inTransaction()) throw new LogicException('Commit cancellation before contacting Cashfree');
        $r = $this->row($id); $policy = CommerceSettings::load($this->db);
        if (in_array($r['status'], ['success','simulated'], true)) return $r;
        if (!$approved && !$policy['refund.automation_enabled'] && ((int)$r['attempts'] > 0 || $r['provider_status'])) $reconcileOnly = true;
        if (!$approved && !$reconcileOnly && (!$policy['refund.automation_enabled'] || in_array($r['status'], ['manual_review','failed'], true))) return $r;
        $token = bin2hex(random_bytes(16)); $now = gmdate('Y-m-d H:i:s');
        $s = $this->db->prepare("UPDATE refund_requests SET lease_token=?,lease_until=? WHERE id=? AND (lease_until IS NULL OR lease_until<?) AND status NOT IN ('success','simulated')");
        $s->execute([$token,gmdate('Y-m-d H:i:s',time()+180),$id,$now]);
        if (!$s->rowCount()) return $this->row($id);
        try {
            $r = $this->row($id);
            $this->gateway ??= new CashfreeRefundGateway();
            if (!$r['request_body'] || !$this->gateway->configured() || $this->gateway->environment() !== $r['environment']) return $this->finish($r,$token,'manual_review','gateway_configuration');
            if ($approved) $this->event($id,$r['status'],'admin','Approved by admin #' . $actor);
            $path = '/orders/' . rawurlencode($r['cf_order_id']) . '/refunds';
            $check = $this->gateway->request('GET',$path . '/' . rawurlencode($r['refund_id']));
            if ($check['code'] === 200) return $this->provider($r,$token,$check['data']);
            if ($check['code'] !== 404) return $this->defer($r,$token,$policy,'lookup_unavailable');
            // A previously observed refund is never created again, even after a stale 404.
            if ($reconcileOnly || $r['provider_status'] || $r['cf_refund_id']) return $this->defer($r,$token,$policy,'provider_not_found');
            if ($r['status'] === 'failed') return $this->finish($r,$token,'failed','provider_terminal');
            if (!$approved && (int)$r['amount_paise'] > (int)round($policy['refund.auto_limit_inr']*100)) return $this->finish($r,$token,'manual_review','approval_required');
            if ((int)$r['attempts'] >= (int)$policy['refund.max_attempts']) return $this->finish($r,$token,'manual_review','retry_limit');
            $order = $this->gateway->request('GET','/orders/' . rawurlencode($r['cf_order_id']));
            $s = $this->db->prepare('SELECT amount FROM payments WHERE id=?'); $s->execute([$r['payment_id']]);
            $paid = (int)round($s->fetchColumn()*100);
            if ($order['code'] !== 200) return $this->defer($r,$token,$policy,'order_lookup_unavailable');
            if (($order['data']['order_status'] ?? '') !== 'PAID' || ($order['data']['order_currency'] ?? '') !== 'INR' || (int)round(($order['data']['order_amount'] ?? -1)*100) !== $paid) return $this->finish($r,$token,'manual_review','order_mismatch');
            // Dashboard-created refunds cannot silently consume this request's budget.
            $all = $this->gateway->request('GET',$path);
            if ($all['code'] !== 200 || !is_array($all['data']) || !array_is_list($all['data'])) return $this->defer($r,$token,$policy,'refund_list_unavailable');
            $s = $this->db->prepare('SELECT refund_id FROM refund_requests WHERE payment_id=?'); $s->execute([$r['payment_id']]); $known = $s->fetchAll(PDO::FETCH_COLUMN);
            foreach ($all['data'] as $other) if (!in_array($other['refund_id'] ?? '',$known,true) && !in_array(strtoupper($other['refund_status'] ?? ''),['FAILED','CANCELLED','REJECTED'],true)) return $this->finish($r,$token,'manual_review','external_refund_detected');
            $this->db->prepare("UPDATE refund_requests SET attempts=attempts+1,status='submitting',updated_at=? WHERE id=? AND lease_token=?")->execute([$now,$id,$token]);
            $r['attempts']++;
            $result = $this->gateway->request('POST',$path,json_decode($r['request_body'],true,512,JSON_THROW_ON_ERROR),$r['idempotency_key']);
            if (in_array($result['code'],[200,201],true)) return $this->provider($r,$token,$result['data']);
            // On ambiguous errors do not invent a new refund: next run looks up this ID.
            if ($result['code'] === 0 || $result['code'] >= 500 || in_array($result['code'],[409,429],true)) return $this->defer($r,$token,$policy,'submission_uncertain');
            return $this->finish($r,$token,'manual_review','provider_rejected');
        } catch (Throwable $e) {
            return $this->defer($r,$token,$policy,'worker_error');
        }
    }
    private function defer(array $r,string $token,array $policy,string $error): array {
        $age = time() - strtotime($r['created_at'] . ' UTC');
        $exhausted = (int)$r['polls'] >= (int)$policy['refund.max_checks'] || $age > $policy['refund.max_pending_hours']*3600;
        $this->db->prepare('UPDATE refund_requests SET polls=polls+1 WHERE id=? AND lease_token=?')->execute([$r['id'],$token]);
        return $this->finish($r,$token,$exhausted ? 'manual_review' : ($r['provider_status'] ? 'pending' : 'retry_wait'),$error,gmdate('Y-m-d H:i:s',time()+(int)$policy['refund.retry_minutes']*60));
    }
    private function provider(array $r,string $token,mixed $data): array {
        if (is_array($data) && array_is_list($data)) {
            $data = array_values(array_filter($data,fn($x)=>($x['refund_id'] ?? '') === $r['refund_id'])); $data = count($data) === 1 ? $data[0] : null;
        }
        if (!is_array($data) || ($data['refund_id'] ?? '') !== $r['refund_id'] || ($data['order_id'] ?? '') !== $r['cf_order_id']
            || (int)round(($data['refund_amount'] ?? -1)*100) !== (int)$r['amount_paise'] || ($data['refund_currency'] ?? '') !== 'INR'
            || (isset($data['cf_payment_id']) && (string)$data['cf_payment_id'] !== (string)$r['cf_payment_id'])) return $this->finish($r,$token,'manual_review','provider_mismatch');
        $this->db->prepare('UPDATE refund_requests SET polls=polls+1 WHERE id=? AND lease_token=?')->execute([$r['id'],$token]);
        $status = strtoupper($data['refund_status'] ?? '');
        $state = match($status) { 'SUCCESS'=>'success', 'PENDING','PENDING_APPROVAL','ONHOLD','ACTIVE'=>'pending', 'FAILED','CANCELLED','REJECTED'=>'failed', default=>'manual_review' };
        $this->db->prepare('UPDATE refund_requests SET provider_status=?,cf_refund_id=?,bank_reference=? WHERE id=? AND lease_token=?')->execute([$status,$data['cf_refund_id'] ?? null,$data['refund_arn'] ?? $data['refund_bank_reference'] ?? null,$r['id'],$token]);
        $policy = CommerceSettings::load($this->db);
        if ($state === 'pending' && time()-strtotime($r['created_at'].' UTC') >  $policy['refund.max_pending_hours']*3600) $state='manual_review';
        if ($state === 'pending' && (int)$r['polls'] >= (int)$policy['refund.max_checks']) $state='manual_review';
        return $this->finish($r,$token,$state,$state === 'manual_review' ? 'provider_review' : null,gmdate('Y-m-d H:i:s',time()+(int)$policy['refund.poll_minutes']*60));
    }
    private function finish(array $r,string $token,string $state,?string $error,?string $next=null): array {
        $this->db->beginTransaction();
        try {
            $s = $this->db->prepare("UPDATE refund_requests SET status=?,error_code=?,next_attempt_at=?,updated_at=?,lease_token=NULL,lease_until=NULL WHERE id=? AND lease_token=? AND status<>'success'");
            $s->execute([$state,$error,$next,gmdate('Y-m-d H:i:s'),$r['id'],$token]);
            if ($s->rowCount()) {
                $this->event((int)$r['id'],$state,'worker',$error);
                if ($state !== $r['status'] && in_array($state,['success','failed','manual_review'],true)) {
                    // Persist an inbox notice in the same transaction as the status.
                    $user=$this->db->prepare('SELECT user_id FROM payments WHERE id=?'); $user->execute([$r['payment_id']]);
                    try {
                        $this->db->prepare('INSERT INTO user_notifications (user_id,type,title,body) VALUES (?,?,?,?)')->execute([$user->fetchColumn(),'refund','Refund update','Refund ' . $r['refund_id'] . ': ' . str_replace('_',' ',$state) . '. INR ' . number_format($r['amount_paise']/100,2,'.','')]);
                    } catch(PDOException $e) { /* Older installations without inbox support still retain refund_events. */ }
                }
            }
            $this->db->commit();
        } catch(Throwable $e) { if ($this->db->inTransaction()) $this->db->rollBack(); throw $e; }
        return $this->row((int)$r['id']);
    }
    public function run(int $limit=25): int {
        $limit=max(1,min(100,$limit));
        $policy=CommerceSettings::load($this->db);
        $active=$policy['refund.automation_enabled'] ? '' : ' AND (attempts>0 OR provider_status IS NOT NULL)';
        $s=$this->db->prepare("SELECT id FROM refund_requests WHERE status IN ('queued','retry_wait','submitting','pending') AND (next_attempt_at IS NULL OR next_attempt_at<=?) AND (lease_until IS NULL OR lease_until<?) $active ORDER BY id LIMIT $limit");
        $s->execute([gmdate('Y-m-d H:i:s'),gmdate('Y-m-d H:i:s')]); $ids=$s->fetchAll(PDO::FETCH_COLUMN);
        foreach($ids as $id) $this->process((int)$id,false,$this->row((int)$id)['status']==='pending');
        return count($ids);
    }
}
