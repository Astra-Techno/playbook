<?php

require_once __DIR__ . '/../src/RefundService.php';

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

$shown = RefundService::publicStatus([
    'id' => 7,
    'status' => 'manual_review',
    'amount_paise' => 1500,
    'refund_id' => 'kc-unit',
    'bank_reference' => null,
]);
check($shown['id'] === 7 && $shown['status'] === 'manual_review' && $shown['amount'] == 15 && $shown['reference'] === 'kc-unit' && $shown['bank_reference'] === null, 'a public refund hides the gateway body');

$db = new PDO('sqlite::memory:');
$service = new RefundService($db);

$needsTransaction = false;
try {
    $service->enqueue(1, null, 'cancel:1', 'cancellation', 100, 0, 1);
} catch (LogicException $e) {
    $needsTransaction = $e->getMessage() === 'Refund reservation requires a transaction';
}
check($needsTransaction, 'a refund is not reserved outside a transaction');

$db->beginTransaction();
$mustCommit = false;
try {
    $service->process(1);
} catch (LogicException $e) {
    $mustCommit = $e->getMessage() === 'Commit cancellation before contacting Cashfree';
}
check($mustCommit, 'a worker does not call the gateway inside the cancellation transaction');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
