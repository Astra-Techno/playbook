<?php

require_once __DIR__ . '/../src/CommerceCheckout.php';

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

function rejected(callable $fn): bool
{
    try {
        $fn();
        return false;
    } catch (InvalidArgumentException $e) {
        return true;
    }
}

$policy = CommerceSettings::defaults();
$policy['booking.minimum_notice_minutes'] = 0;
$policy['booking.advance_hours'] = 0;

CommerceCheckout::validateTime('2027-06-01 10:00:00', '2027-06-01 11:00:00', $policy);
check(true, 'a one-hour slot on the hour is accepted');

CommerceCheckout::validateTime('2027-06-01 10:30:00', '2027-06-01 11:30:00', $policy);
check(true, 'a slot on the half hour is accepted');

check(rejected(fn() => CommerceCheckout::validateTime('2027-06-01 10:15:00', '2027-06-01 11:15:00', $policy)), 'a start off the half hour is rejected');
check(rejected(fn() => CommerceCheckout::validateTime('2027-06-01 11:00:00', '2027-06-01 10:00:00', $policy)), 'an end before the start is rejected');
check(rejected(fn() => CommerceCheckout::validateTime('2027-06-01 10:00:00', '2027-06-02 11:00:00', $policy)), 'a range longer than 24 hours is rejected');

$close = $policy;
$close['booking.minimum_notice_minutes'] = 10080;
check(rejected(fn() => CommerceCheckout::validateTime(date('Y-m-d H:00:00', time() + 3600), date('Y-m-d H:00:00', time() + 7200), $close)), 'a slot inside the notice window is rejected');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
