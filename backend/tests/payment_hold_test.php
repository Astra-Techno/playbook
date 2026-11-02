<?php

require_once __DIR__ . '/../src/PaymentHold.php';

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

check(PaymentHold::expiresAt('2026-11-02 18:00:00') === '2026-11-02 18:10:00', 'a hold lasts 10 minutes');
check(PaymentHold::blocks(null, '2026-11-02 18:10:00', '2026-11-02 18:05:00', null, 0) === true, 'an unfinished hold blocks the slot');
check(PaymentHold::blocks(null, '2026-11-02 18:10:00', '2026-11-02 18:10:00', 4, 0) === false, 'an expired hold releases the slot');
check(PaymentHold::blocks('2026-11-02 18:04:00', '2026-11-02 18:10:00', '2026-11-02 18:05:00', 4, 0) === false, 'a released hold does not block');
check(PaymentHold::blocks(null, '2026-11-02 18:10:00', '2026-11-02 18:05:00', 9, 9) === false, 'the payer\'s own hold does not block fulfilment');
check(PaymentHold::blocks(null, '2026-11-02 18:10:00', '2026-11-02 18:05:00', 9, 3) === true, 'another payer still sees the hold');

$slots = PaymentHold::slots([
    'court_id' => 4,
    'sub_court_id' => 8,
    'slots' => [
        ['start_time' => '2026-11-02 18:00:00', 'end_time' => '2026-11-02 19:00:00'],
    ],
]);
check(count($slots) === 1 && $slots[0]['sub_court_id'] === 8, 'a checkout payload becomes one hold per slot');
check(PaymentHold::slots(['court_id' => 4, 'plan_id' => 2]) === [], 'a subscription payload has no slot hold');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
