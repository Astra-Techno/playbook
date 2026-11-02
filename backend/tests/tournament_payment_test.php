<?php

require_once __DIR__ . '/../src/TournamentPayment.php';

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

$now = '2026-12-01 09:05:00';
$held = TournamentPayment::decide('pending', 7, 7, 100, 100, 'active', '2026-12-01 09:10:00', $now, 2, 2);
check($held['ok'] === true && $held['state'] === 'confirmed' && $held['hold'] === 'consumed', 'a paid entry with a live hold is confirmed');

$lateOpen = TournamentPayment::decide('pending', 7, 7, 100, 100, 'active', '2026-12-01 09:00:00', $now, 2, 1);
check($lateOpen['state'] === 'confirmed', 'a late payment confirms when a seat is still open');

$lateFull = TournamentPayment::decide('pending', 7, 7, 100, 100, 'active', '2026-12-01 09:00:00', $now, 2, 2);
check($lateFull['ok'] === false && $lateFull['refund'] === true, 'a late payment is refunded when the category is full');

$unlimited = TournamentPayment::decide('pending', 7, 7, 50, 50, null, null, $now, 0, 40);
check($unlimited['state'] === 'confirmed', 'capacity 0 still confirms a late payment');

$mismatch = TournamentPayment::decide('pending', 7, 7, 100, 90, 'active', '2026-12-01 09:10:00', $now, 2, 0);
check($mismatch['refund'] === true, 'a short payment is not a confirmation');

$stranger = TournamentPayment::decide('pending', 7, 8, 100, 100, 'active', '2026-12-01 09:10:00', $now, 2, 0);
check($stranger['ok'] === false, 'another player cannot confirm the entry');

$again = TournamentPayment::decide('confirmed', 7, 7, 100, 100, 'consumed', null, $now, 2, 2);
check($again['ok'] === true && $again['hold'] === 'unchanged', 'a confirmed entry stays confirmed');

$queued = TournamentPayment::decide('waitlisted', 7, 7, 100, 100, null, null, $now, 2, 2);
check($queued['refund'] === true, 'a waitlisted entry is not confirmed by payment');

$needsApproval = TournamentPayment::decide('pending', 7, 7, 100, 100, 'active', '2026-12-01 09:10:00', $now, 2, 0, true);
check($needsApproval['state'] === 'pending_approval', 'a paid entry that needs approval waits for the organizer');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
