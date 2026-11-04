<?php

require_once __DIR__ . '/../src/CommerceSettings.php';

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

$policy = CommerceSettings::defaults();
$snapshot = [
    'policy' => $policy,
    'price' => [
        'venue' => ['total' => 10000],
        'fee' => ['total' => 1000],
    ],
];

$full = CommerceSettings::refund($snapshot, 12, false);
check($full['venue_percent'] === 100 && $full['venue'] === 10000 && $full['fee'] === 1000 && $full['total'] === 11000, '12 hours notice refunds the venue and the fee');

$partial = CommerceSettings::refund($snapshot, 6, false);
check($partial['venue_percent'] === 50 && $partial['venue'] === 5000 && $partial['fee'] === 0 && $partial['total'] === 5000, '6 hours notice refunds half the venue and keeps the fee');

$late = CommerceSettings::refund($snapshot, 1, false);
check($late['venue_percent'] === 0 && $late['total'] === 0, 'a late cancellation refunds nothing');

$byVenue = CommerceSettings::refund($snapshot, 1, true);
check($byVenue['venue_percent'] === 100 && $byVenue['fee'] === 1000 && $byVenue['total'] === 11000, 'a venue cancellation refunds the venue and the fee');

$never = $policy;
$never['cancellation.fee_refund'] = 'never';
$noFee = CommerceSettings::refund(['policy' => $never, 'price' => $snapshot['price']], 24, false);
check($noFee['venue'] === 10000 && $noFee['fee'] === 0, 'a fee set to never stays with the platform on a full refund');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
