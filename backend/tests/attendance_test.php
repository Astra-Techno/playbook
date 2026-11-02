<?php

require_once __DIR__ . '/../src/Attendance.php';

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

$start = '2026-11-02 18:00:00';
$end = '2026-11-02 19:00:00';

$early = Attendance::decide('check_in', null, 'confirmed', $start, $end, '2026-11-02 17:20:00');
check($early['ok'] === false, 'check-in stays closed more than 30 minutes before the start');

$open = Attendance::decide('check_in', null, 'confirmed', $start, $end, '2026-11-02 17:30:00');
check($open['ok'] === true && $open['attendance'] === 'checked_in', 'check-in opens 30 minutes before the start');

$late = Attendance::decide('check_in', null, 'confirmed', $start, $end, '2026-11-02 19:00:00');
check($late['ok'] === false, 'check-in closes when the booking ends');

$soon = Attendance::decide('no_show', null, 'confirmed', $start, $end, '2026-11-02 18:10:00');
check($soon['ok'] === false, 'a no-show waits 15 minutes after the start');

$missed = Attendance::decide('no_show', null, 'confirmed', $start, $end, '2026-11-02 18:15:00');
check($missed['ok'] === true && $missed['attendance'] === 'no_show', 'a no-show can be marked 15 minutes after the start');

$again = Attendance::decide('check_in', 'checked_in', 'confirmed', $start, $end, '2026-11-02 18:10:00');
check($again['ok'] === false, 'a second check-in is refused');

$flip = Attendance::decide('no_show', 'checked_in', 'confirmed', $start, $end, '2026-11-02 18:20:00');
check($flip['ok'] === false, 'a checked-in booking is not marked as a no-show');

$cancelled = Attendance::decide('check_in', null, 'cancelled', $start, $end, '2026-11-02 18:10:00');
check($cancelled['ok'] === false, 'a cancelled booking is left unchanged');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
