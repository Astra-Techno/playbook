<?php

require_once __DIR__ . '/../src/PlayerStats.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) { echo "ok  $message\n"; return; }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$now = '2026-11-27 10:00:00';
$rows = [
    ['start_time' => '2026-11-29 19:00:00', 'end_time' => '2026-11-29 20:00:00', 'attendance' => null, 'court_type' => 'turf'], // future
    ['start_time' => '2026-11-20 19:00:00', 'end_time' => '2026-11-20 20:30:00', 'attendance' => 'checked_in', 'court_type' => 'turf'],
    ['start_time' => '2026-11-15 07:00:00', 'end_time' => '2026-11-15 08:00:00', 'attendance' => 'no_show', 'court_type' => 'shuttle'],
    ['start_time' => '2026-11-10 19:00:00', 'end_time' => '2026-11-10 20:00:00', 'attendance' => 'checked_in', 'court_type' => 'turf'],
    ['start_time' => '2026-11-01 06:00:00', 'end_time' => '2026-11-01 07:00:00', 'attendance' => null, 'court_type' => 'tennis'],
];
$s = PlayerStats::compute($rows, $now);

check($s['games'] === 4, 'only played games count');
check($s['hours'] === 4.5, 'hours add up (1.5 + 1 + 1 + 1)');
check($s['show_up_rate'] === 67 && $s['marked'] === 3, 'show-up rate over marked games only (2 of 3)');
check($s['sports'] === ['turf', 'shuttle', 'tennis'], 'top sports by games');
check(PlayerStats::compute([$rows[4]], $now)['show_up_rate'] === null, 'no rate until a venue marks a game');
check(PlayerStats::compute([], $now) === ['hours' => 0.0, 'games' => 0, 'show_up_rate' => null, 'marked' => 0, 'sports' => []], 'empty season');

exit($failed ? 1 : 0);
