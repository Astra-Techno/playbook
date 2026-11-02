<?php

require_once __DIR__ . '/../src/RefundWebhookPlan.php';
require_once __DIR__ . '/../src/CashfreeRefundGateway.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) {
        echo "ok  $message\n";
        return;
    }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

check(RefundWebhookPlan::decide(false, true) === RefundWebhookPlan::RECONCILE, 'a first delivery of a known refund is a reconcile');
check(RefundWebhookPlan::decide(true, true) === RefundWebhookPlan::DUPLICATE, 'the same body does not reconcile again');
check(RefundWebhookPlan::decide(false, false) === RefundWebhookPlan::IGNORE, 'an unknown refund is not created from the webhook');
check(RefundWebhookPlan::mayCreateProviderRefund(true, null, null) === false, 'a reconcile does not create a provider refund');
check(RefundWebhookPlan::mayCreateProviderRefund(false, 'SUCCESS', null) === false, 'a refund already seen at the provider is not created again');
check(RefundWebhookPlan::mayCreateProviderRefund(false, null, null) === true, 'a queued refund with no provider id can still be submitted by the worker');

$secret = 'unit-test-secret';
$raw = '{"data":{"refund":{"refund_id":"kc-replay"}}}';
$timestamp = '1730500000';
$signature = base64_encode(hash_hmac('sha256', $timestamp . $raw, $secret, true));
check(RefundWebhookSignature::valid($raw, $timestamp, $signature, $secret), 'the original delivery signature matches');
check(RefundWebhookSignature::valid($raw . ' ', $timestamp, $signature, $secret) === false, 'a changed body does not keep the signature');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
