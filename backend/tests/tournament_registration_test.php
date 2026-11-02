<?php

require_once __DIR__ . '/../src/TournamentRegistration.php';

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

check(TournamentRegistration::idempotencyKey('entry-001') === 'entry-001', 'a registration key is kept');
check(TournamentRegistration::idempotencyKey('short') === false, 'a short key is rejected');
check(TournamentRegistration::expiresAt('2026-12-01 09:00:00') === '2026-12-01 09:10:00', 'an unpaid entry holds a seat for 10 minutes');

check(TournamentRegistration::countsAsSeat('confirmed', null, null, '2026-12-01 09:00:00') === true, 'a free entry keeps its seat');
check(TournamentRegistration::countsAsSeat('pending', 'active', '2026-12-01 09:10:00', '2026-12-01 09:05:00') === true, 'an unpaid entry keeps its seat until the hold ends');
check(TournamentRegistration::countsAsSeat('pending', 'active', '2026-12-01 09:10:00', '2026-12-01 09:10:00') === false, 'an expired hold gives the seat back');
check(TournamentRegistration::countsAsSeat('waitlisted', null, null, '2026-12-01 09:00:00') === false, 'a waitlisted entry is not a taken seat');

$open = TournamentRegistration::decide(2, 1, false, 0, false);
check($open['ok'] === true && $open['state'] === 'confirmed' && $open['hold'] === false, 'a free open seat is confirmed');
$paid = TournamentRegistration::decide(2, 1, false, 100, false);
check($paid['state'] === 'pending' && $paid['hold'] === true, 'a paid open seat stays pending behind a hold');
$full = TournamentRegistration::decide(2, 2, false, 0, false);
check($full['ok'] === false, 'a full category without a waitlist refuses the entry');
$wait = TournamentRegistration::decide(2, 2, true, 50, false);
check($wait['state'] === 'waitlisted' && $wait['hold'] === false, 'a full category with a waitlist queues the entry');
$unlimited = TournamentRegistration::decide(0, 40, false, 0, false);
check($unlimited['state'] === 'confirmed', 'capacity 0 does not close the category');
check(TournamentRegistration::decide(2, 0, false, 0, true)['ok'] === false, 'the same player cannot enter twice');
check(TournamentRegistration::countsAsSeat('pending_approval', null, null, '2026-12-01 09:00:00') === true, 'an entry waiting for approval keeps its seat');
$review = TournamentRegistration::decide(2, 0, false, 0, false, true);
check($review['state'] === 'pending_approval' && $review['hold'] === false, 'a free entry that needs approval waits for the organizer');
$payFirst = TournamentRegistration::decide(2, 0, false, 100, false, true);
check($payFirst['state'] === 'pending' && $payFirst['hold'] === true, 'a paid entry pays before approval');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
