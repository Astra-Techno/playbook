<?php

require_once __DIR__ . '/../src/TournamentCheckIn.php';

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

$open = TournamentCheckIn::decide('confirmed', null, '2026-12-01 09:00:00', '2026-12-01 18:00:00', '2026-12-01 08:40:00');
check($open['ok'] === true, 'check-in is open 30 minutes before the event');

$early = TournamentCheckIn::decide('confirmed', null, '2026-12-01 09:00:00', '2026-12-01 18:00:00', '2026-12-01 08:29:00');
check($early['ok'] === false, 'check-in stays closed before that window');

$closed = TournamentCheckIn::decide('confirmed', null, '2026-12-01 09:00:00', '2026-12-01 18:00:00', '2026-12-01 18:00:00');
check($closed['ok'] === false, 'check-in closes when the event ends');

$again = TournamentCheckIn::decide('confirmed', '2026-12-01 09:00:00', '2026-12-01 09:00:00', '2026-12-01 18:00:00', '2026-12-01 09:05:00');
check($again['ok'] === false, 'a second check-in is refused');

$pending = TournamentCheckIn::decide('pending', null, null, null, '2026-12-01 09:00:00');
check($pending['ok'] === false, 'a pending entry stays unchecked');

$untimed = TournamentCheckIn::decide('confirmed', null, null, null, '2026-12-01 09:00:00');
check($untimed['ok'] === true, 'a confirmed entry with no event times can be checked in');

$code = TournamentCheckIn::code();
check(TournamentCheckIn::codeValue($code) === $code, 'a generated door code is eight safe characters');
check(TournamentCheckIn::codeValue('abcd2345') === 'ABCD2345', 'a door code is read in upper case');
check(TournamentCheckIn::codeValue('ABCD234O') === false, 'a door code rejects O');
check(TournamentCheckIn::codeValue('SHORT') === false, 'a short door code is rejected');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
