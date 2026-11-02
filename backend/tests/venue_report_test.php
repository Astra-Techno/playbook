<?php

require_once __DIR__ . '/../src/VenueReport.php';

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

check(VenueReport::canView(false, true) === true, 'the venue owner can open the report');
check(VenueReport::canView(true, false) === true, 'an admin can open the report');
check(VenueReport::canView(false, false) === false, 'staff and other players cannot open the report');

$report = VenueReport::build([
    ['status' => 'confirmed', 'total_price' => 100, 'user_id' => 1],
    ['status' => 'confirmed', 'total_price' => 50, 'user_id' => 1],
    ['status' => 'confirmed', 'total_price' => 40, 'user_id' => 0],
    ['status' => 'cancelled', 'total_price' => 80, 'user_id' => 2],
    ['status' => 'pending', 'total_price' => 10, 'user_id' => 3],
], 120.5);

check($report['booking_gross'] === 190.0, 'booking prices add the confirmed rows');
check($report['collected'] === 120.5, 'collected money stays the refunded payment total');
check($report['booking_gross'] !== $report['collected'], 'booking prices and collected money stay separate');
check($report['confirmed_count'] === 3 && $report['cancelled_count'] === 1, 'pending rows stay out of both counts');
check($report['cancel_rate'] === 25.0, 'the cancel rate uses confirmed and cancelled rows');
check($report['unique_players'] === 1 && $report['repeat_players'] === 1, 'a walk-in is left out of repeat players');
check(!array_key_exists('paid_out', $report), 'an owner payout is left off the venue report');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
