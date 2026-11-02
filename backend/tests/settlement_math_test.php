<?php

require_once __DIR__ . '/../src/SettlementMath.php';

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

check(SettlementMath::notYetPaidOut(1000, 400) === 600.0, 'collected minus payouts is what is not yet paid out');
check(SettlementMath::notYetPaidOut(100, 250) === -150.0, 'a payout larger than collected stays visible');
check(SettlementMath::notYetPaidOut(80.5, 0.2) === 80.3, 'the remainder is rounded to paise');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
