<?php

require_once __DIR__ . '/../src/SquadMatch.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) { echo "ok  $message\n"; return; }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$now = '2026-11-27 10:00:00';
$booking = ['id' => 7, 'user_id' => 3, 'court_id' => 9, 'status' => 'confirmed', 'start_time' => '2026-11-28 19:00:00', 'end_time' => '2026-11-28 20:30:00', 'court_name' => 'Kick Arena', 'court_type' => 'turf'];

$ok = SquadMatch::fromBooking($booking, 3, 2, $now);
check($ok['ok'] === true, 'booker can post open spots');
check($ok['fields']['title'] === 'Need 2 at Kick Arena' && $ok['fields']['sport'] === 'turf', 'title and sport come from the booking');
check($ok['fields']['date'] === '2026-11-28' && $ok['fields']['start_time'] === '19:00:00' && $ok['fields']['end_time'] === '20:30:00', 'date and times copied');
check($ok['fields']['booking_id'] === 7 && $ok['fields']['players_needed'] === 2, 'linked to the booking');

check(SquadMatch::fromBooking(null, 3, 2, $now)['http'] === 404, 'missing booking');
check(SquadMatch::fromBooking($booking, 4, 2, $now)['http'] === 403, 'only the booker');
check(SquadMatch::fromBooking(['status' => 'cancelled'] + $booking, 3, 2, $now)['http'] === 409, 'not for cancelled bookings');
check(SquadMatch::fromBooking(['start_time' => '2026-11-27 09:00:00'] + $booking, 3, 2, $now)['http'] === 409, 'not once the game started');
check(SquadMatch::fromBooking($booking, 3, 0, $now)['http'] === 422 && SquadMatch::fromBooking($booking, 3, 21, $now)['http'] === 422, '1 to 20 spots');

exit($failed ? 1 : 0);
