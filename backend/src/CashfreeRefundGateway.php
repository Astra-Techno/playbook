<?php

interface RefundGateway {
    public function environment(): string;
    public function configured(): bool;
    public function request(string $method, string $endpoint, array $body = [], ?string $idempotency = null): array;
}

final class CashfreeRefundGateway implements RefundGateway {
    public function __construct() { require_once __DIR__ . '/../config/cashfree.php'; }
    public function environment(): string { return CASHFREE_ENV; }
    public function configured(): bool {
        return CASHFREE_APP_ID && CASHFREE_SECRET_KEY && CASHFREE_APP_ID !== 'your_cashfree_app_id' && CASHFREE_SECRET_KEY !== 'your_cashfree_secret_key';
    }
    public function request(string $method, string $endpoint, array $body = [], ?string $idempotency = null): array {
        if (!$this->configured()) return ['code' => 0, 'data' => null];
        $headers = ['x-client-id: ' . CASHFREE_APP_ID, 'x-client-secret: ' . CASHFREE_SECRET_KEY,
            'x-api-version: ' . CASHFREE_API_VERSION, 'Content-Type: application/json', 'Accept: application/json'];
        if ($idempotency !== null) $headers[] = 'x-idempotency-key: ' . $idempotency;
        $ch = curl_init(CASHFREE_BASE_URL . $endpoint);
        curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => $headers,
            CURLOPT_SSL_VERIFYPEER => true, CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_CONNECTTIMEOUT => 5, CURLOPT_TIMEOUT => 15, CURLOPT_FOLLOWLOCATION => false]);
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_THROW_ON_ERROR));
        }
        $raw = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        if (curl_errno($ch)) $code = 0;
        curl_close($ch);
        // Never return/log credentials or unredacted provider messages.
        return ['code' => $code, 'data' => is_string($raw) ? json_decode($raw, true) : null];
    }
}

final class RefundWebhookSignature {
    public static function valid(string $raw, string $timestamp, string $signature, string $secret): bool {
        if ($secret === '' || $secret === 'your_cashfree_secret_key' || !preg_match('/^[0-9]{10,16}$/', $timestamp) || $signature === '') return false;
        return hash_equals(base64_encode(hash_hmac('sha256', $timestamp . $raw, $secret, true)), $signature);
    }
}
