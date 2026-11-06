<?php

require_once __DIR__ . '/../src/PayoutRequest.php';

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

$ok = PayoutRequest::plan(600, 250, false, ' bank ');
check($ok['ok'] === true && $ok['amount'] === 250.0 && $ok['note'] === 'bank', 'an amount within the unpaid balance can be requested');
check(PayoutRequest::plan(600, 250, true, '')['ok'] === false, 'a second request waits until the open one is closed');
check(PayoutRequest::plan(600, 0, false, '')['ok'] === false, 'a zero amount is refused');
check(PayoutRequest::plan(100, 150, false, '')['ok'] === false, 'a request cannot pass what has not yet been paid out');
check(PayoutRequest::plan(100, 50, false, str_repeat('a', 201))['ok'] === false, 'a long note is refused');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
