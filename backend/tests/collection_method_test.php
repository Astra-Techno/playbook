<?php

require_once __DIR__ . '/../src/CollectionMethod.php';

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

check(CollectionMethod::forWalkIn(null) === 'pay_at_venue', 'an omitted method is pay at venue');
check(CollectionMethod::forWalkIn(' cash ') === 'cash', 'cash is kept');
check(CollectionMethod::forWalkIn('external_upi') === 'external_upi', 'external UPI is kept');
check(CollectionMethod::forWalkIn('card') === false, 'an unknown method is rejected');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
