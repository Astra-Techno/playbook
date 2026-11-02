<?php

require_once __DIR__ . '/../src/TournamentRegistration.php';
require_once __DIR__ . '/../src/TournamentRoster.php';
require_once __DIR__ . '/../src/TournamentApproval.php';

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

$first = TournamentRegistration::decide(1, 0, false, 0, false);
$second = TournamentRegistration::decide(1, $first['ok'] ? 1 : 0, false, 0, false);
check($first['state'] === 'confirmed' && $second['ok'] === false, 'the second player loses the last seat');

$held = TournamentRegistration::decide(1, 0, false, 100, false);
$late = TournamentRegistration::decide(1, 1, false, 0, false);
check($held['state'] === 'pending' && $late['ok'] === false, 'a live unpaid hold keeps the seat from the next player');

$doubles = TournamentRoster::extras('doubles', [['display_name' => 'Ada']], 7);
check($doubles['ok'] === true && count($doubles['members']) === 1, 'doubles takes one partner');
check(TournamentRoster::extras('singles', [['display_name' => 'Ada']], 7)['ok'] === false, 'singles stays the captain only');
check(TournamentRoster::extras('team', [], 7)['ok'] === false, 'a team needs partners besides the captain');

$approve = TournamentApproval::decide('pending_approval', 'approve');
$reject = TournamentApproval::decide('pending_approval', 'reject');
check($approve['state'] === 'confirmed' && $reject['state'] === 'cancelled', 'approval confirms and rejection cancels');
check(TournamentApproval::decide('confirmed', 'approve')['ok'] === false, 'a confirmed entry is not reviewed again');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
