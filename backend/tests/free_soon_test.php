<?php

date_default_timezone_set('Asia/Kolkata'); // half-hour offset catches naive hour maths
require_once __DIR__ . '/../src/FreeSoon.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) { echo "ok  $message\n"; return; }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$w = FreeSoon::windows('2026-11-25 19:00:00', 3);
check(count($w) === 3, 'three hours probed');
check($w[0] === ['2026-11-25 19:00:00', '2026-11-25 20:00:00'], 'first window starts at the given hour');
check($w[2][0] === '2026-11-25 21:00:00', 'windows step one hour');
check(FreeSoon::windows('2026-11-25 19:40:00', 1)[0][0] === '2026-11-25 19:00:00', 'snaps down to the full hour');
$late = FreeSoon::windows('2026-11-25 22:00:00', 3);
check(count($late) === 2 && $late[1][1] === '2026-11-26 00:00:00', 'stops at midnight, last window may end at 00:00');
check(FreeSoon::windows('nonsense', 3) === [], 'bad time gives no windows');
check(count(FreeSoon::windows('2026-11-25 08:00:00', 99)) === 6, 'at most six hours');
check(FreeSoon::ids('3,5,x,5,-2,0') === [3, 5], 'ids are positive and unique');
check(count(FreeSoon::ids(implode(',', range(1, 30)))) === 10, 'at most ten venues');

$day = FreeSoon::dayWindows('2026-11-25');
check(count($day) === 17, 'day strip has 17 hours');
check($day[0] === ['2026-11-25 06:00:00', '2026-11-25 07:00:00'], 'strip starts at 6 AM');
check($day[16][1] === '2026-11-25 23:00:00', 'last slot ends at 11 PM');
check(FreeSoon::dayWindows('25-11-2026') === [] && FreeSoon::dayWindows('2026-11-25; DROP') === [], 'bad dates give no strip');
check(FreeSoon::stateChar(false, true, true) === 'c', 'closed wins');
check(FreeSoon::stateChar(true, false, true) === 't', 'taken');
check(FreeSoon::stateChar(true, true, true) === 'p' && FreeSoon::stateChar(true, true, false) === 'f', 'free at peak and off-peak');

exit($failed ? 1 : 0);
