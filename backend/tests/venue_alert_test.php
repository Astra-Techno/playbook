<?php

require_once __DIR__ . '/../src/VenueAlert.php';

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

$now = '2026-12-01 09:00:00';
$due = VenueAlert::plan([
    [
        'id' => 8,
        'court_id' => 3,
        'status' => 'confirmed',
        'attendance' => null,
        'start_time' => '2026-12-01 09:30:00',
        'end_time' => '2026-12-01 10:30:00',
        'guest_name' => ' Ada ',
        'guest_phone' => '9999900000',
        'player_name' => 'Someone',
    ],
    [
        'id' => 8,
        'court_id' => 3,
        'status' => 'confirmed',
        'attendance' => null,
        'start_time' => '2026-12-01 09:30:00',
        'end_time' => '2026-12-01 10:30:00',
        'guest_name' => 'Ada',
    ],
], [], $now);
check($due['ok'] === true && count($due['alerts']) === 1, 'one booking makes one arrival alert');
check($due['alerts'][0]['event_key'] === 'arrival:8', 'the alert key is the booking');
check($due['alerts'][0]['body'] === 'Ada is due at 09:30.', 'the body names the player and the time');
check(str_contains(json_encode($due['alerts'][0]), '99999') === false, 'the alert leaves the phone out');

$again = VenueAlert::plan([
    [
        'id' => 8,
        'court_id' => 3,
        'status' => 'confirmed',
        'attendance' => null,
        'start_time' => '2026-12-01 09:30:00',
        'end_time' => '2026-12-01 10:30:00',
        'guest_name' => 'Ada',
    ],
], ['arrival:8'], $now);
check($again['alerts'] === [], 'a second pass does not repeat the alert');

check(VenueAlert::plan([
    [
        'id' => 2,
        'court_id' => 3,
        'status' => 'confirmed',
        'attendance' => 'checked_in',
        'start_time' => '2026-12-01 09:10:00',
        'end_time' => '2026-12-01 10:00:00',
        'player_name' => 'Bo',
    ],
], [], $now)['alerts'] === [], 'a marked arrival stays quiet');
check(VenueAlert::plan([
    [
        'id' => 3,
        'court_id' => 3,
        'status' => 'pending',
        'attendance' => null,
        'start_time' => '2026-12-01 09:10:00',
        'end_time' => '2026-12-01 10:00:00',
        'player_name' => 'Cy',
    ],
], [], $now)['alerts'] === [], 'a pending booking stays quiet');
check(VenueAlert::plan([
    [
        'id' => 4,
        'court_id' => 3,
        'status' => 'confirmed',
        'attendance' => null,
        'start_time' => '2026-12-01 11:00:00',
        'end_time' => '2026-12-01 12:00:00',
        'player_name' => 'Dee',
    ],
], [], $now)['alerts'] === [], 'a booking more than an hour away stays quiet');
check(VenueAlert::plan([], [], 'soon')['ok'] === false, 'the clock must be a date and time');

$many = [];
for ($i = 1; $i <= 51; $i++) {
    $many[] = ['id' => $i];
}
$many[] = ['id' => 1];
$many[] = ['id' => 0];
$keys = VenueAlert::keys($many);
check(count($keys) === 50 && $keys[0] === 'arrival:1' && $keys[49] === 'arrival:50', 'a refresh looks up at most 50 booking keys');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
