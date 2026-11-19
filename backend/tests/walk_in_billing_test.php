<?php

require_once __DIR__ . '/../src/WalkInBilling.php';

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

$zone = new DateTimeZone('Asia/Kolkata');
$now = new DateTimeImmutable('2026-11-19 15:30:00', $zone);

check(WalkInBilling::startHasPassed('2026-11-19 15:00:00', $now) === true, 'an earlier hour has passed');
check(WalkInBilling::startHasPassed('2026-11-19 15:30:00', $now) === true, 'the current minute has passed');
check(WalkInBilling::startHasPassed('2026-11-19 16:00:00', $now) === false, 'a later hour has not passed');

check(
    WalkInBilling::attendanceOnCreate(true, '2026-11-19 14:00:00', $now) === 'checked_in',
    'a past walk-in is checked in for billing'
);
check(
    WalkInBilling::attendanceOnCreate(true, '2026-11-19 18:00:00', $now) === null,
    'a future walk-in stays unmarked'
);
check(
    WalkInBilling::attendanceOnCreate(false, '2026-11-19 14:00:00', $now) === null,
    'a non walk-in is not auto-marked'
);

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
