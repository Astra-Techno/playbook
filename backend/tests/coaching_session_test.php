<?php

require_once __DIR__ . '/../src/CoachingSession.php';

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

$plan = CoachingSession::plan('Morning drills', 'Ada', 2, '2026-12-01 06:00:00', '2026-12-01 07:00:00', true);
check($plan['ok'] === true && $plan['capacity'] === 2, 'a class keeps the instructor name and the capacity');
check(CoachingSession::plan(' ', 'Ada', 2, '2026-12-01 06:00:00', '2026-12-01 07:00:00', true)['ok'] === false, 'a class needs a name');
check(CoachingSession::plan('Drills', 'Ada', 0, '2026-12-01 06:00:00', '2026-12-01 07:00:00', true)['ok'] === false, 'capacity starts at one');
check(CoachingSession::plan('Drills', 'Ada', 2, '2026-12-01 07:00:00', '2026-12-01 06:00:00', true)['ok'] === false, 'the end must be after the start');
check(CoachingSession::plan('Drills', 'Ada', 2, '2026-12-01 06:00:00', '2026-12-01 07:00:00', false)['ok'] === false, 'a busy court refuses the class');
check(CoachingSession::canCancel('scheduled') === true && CoachingSession::canCancel('cancelled') === false, 'only a scheduled class can be cancelled');

$joined = CoachingSession::enroll('scheduled', 2, 1, ' Bo ', 8, [3]);
check($joined['ok'] === true && $joined['name'] === 'Bo', 'a named player can join');
check(CoachingSession::enroll('scheduled', 2, 2, 'Cy', null, [])['ok'] === false, 'a full class refuses another player');
check(CoachingSession::enroll('scheduled', 2, 0, 'Ada', 8, [8])['ok'] === false, 'the same player cannot join twice');
check(CoachingSession::enroll('cancelled', 2, 0, 'Ada', null, [])['ok'] === false, 'a cancelled class is closed');

check(CoachingSession::attendance('scheduled', 'enrolled', null, 'present')['attendance'] === 'present', 'a player can be marked present');
check(CoachingSession::attendance('scheduled', 'enrolled', 'present', 'absent')['ok'] === false, 'a second mark is refused');
check(CoachingSession::attendance('cancelled', 'enrolled', null, 'present')['ok'] === false, 'a cancelled class does not take attendance');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
