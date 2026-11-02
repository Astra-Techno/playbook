<?php

require_once __DIR__ . '/../src/OccupancyMath.php';

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

$one = OccupancyMath::summarize('2026-11-02', '06:00:00', '22:00:00', 0, [
    ['start' => '2026-11-02 18:00:00', 'end' => '2026-11-02 19:00:00', 'status' => 'confirmed'],
]);
check($one['booked_minutes'] === 60 && $one['open_minutes'] === 960 && $one['confirmed_count'] === 1, 'one hour inside a 16 hour venue counts');

$spaces = OccupancyMath::summarize('2026-11-02', '06:00:00', '22:00:00', 2, [
    ['start' => '2026-11-02 18:00:00', 'end' => '2026-11-02 19:00:00', 'status' => 'confirmed', 'sub_court_id' => 8],
    ['start' => '2026-11-02 18:00:00', 'end' => '2026-11-02 19:00:00', 'status' => 'confirmed', 'sub_court_id' => null],
]);
check($spaces['open_minutes'] === 1920 && $spaces['booked_minutes'] === 60 && $spaces['confirmed_count'] === 1, 'each space adds open time and a venue-level row does not fill a space');

$edge = OccupancyMath::summarize('2026-11-02', '06:00:00', '22:00:00', 0, [
    ['start' => '2026-11-02 21:00:00', 'end' => '2026-11-02 23:00:00', 'status' => 'confirmed'],
    ['start' => '2026-11-02 05:00:00', 'end' => '2026-11-02 06:00:00', 'status' => 'confirmed'],
    ['start' => '2026-11-02 10:00:00', 'end' => '2026-11-02 11:00:00', 'status' => 'cancelled'],
]);
check($edge['booked_minutes'] === 60 && $edge['confirmed_count'] === 1, 'only the part inside open hours counts, and a cancelled row is skipped');

$shared = OccupancyMath::summarize('2026-11-02', '06:00:00', '22:00:00', 1, [
    ['start' => '2026-11-02 18:00:00', 'end' => '2026-11-02 19:00:00', 'status' => 'confirmed', 'sub_court_id' => 3],
    ['start' => '2026-11-02 18:00:00', 'end' => '2026-11-02 19:00:00', 'status' => 'confirmed', 'sub_court_id' => 3],
]);
check($shared['booked_minutes'] === 120 && $shared['open_minutes'] === 960, 'shared bookings in the same hour are both counted');

$night = OccupancyMath::summarize('2026-11-02', '18:00:00', '02:00:00', 0, [
    ['start' => '2026-11-02 23:00:00', 'end' => '2026-11-03 01:00:00', 'status' => 'confirmed'],
]);
check($night['booked_minutes'] === 120 && $night['open_minutes'] === 480, 'an overnight venue counts the booking that crosses midnight');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
