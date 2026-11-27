<?php

require_once __DIR__ . '/../src/PlayerCrew.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) { echo "ok  $message\n"; return; }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$now = '2026-11-27 10:00:00'; // Friday
// Next same slot: Wednesday 7 PM game -> next Wednesday 7 PM, length kept.
check(PlayerCrew::nextSameSlot('2026-11-18 19:00:00', '2026-11-18 20:30:00', $now) === ['2026-12-02 19:00:00', '2026-12-02 20:30:00'], 'next Wednesday, same length');
check(PlayerCrew::nextSameSlot('2026-11-20 18:00:00', '2026-11-20 19:00:00', $now)[0] === '2026-11-27 18:00:00', 'same weekday later today');
check(PlayerCrew::nextSameSlot('2026-11-20 08:00:00', '2026-11-20 09:00:00', $now)[0] === '2026-12-04 08:00:00', 'same weekday but earlier today -> next week');

$me = 1;
$people = [
    1 => ['id' => 1, 'name' => 'Me', 'avatar_url' => null],
    2 => ['id' => 2, 'name' => 'Arjun', 'avatar_url' => null],
    3 => ['id' => 3, 'name' => 'Ravi', 'avatar_url' => 'r.png'],
    4 => ['id' => 4, 'name' => 'Sam', 'avatar_url' => null],
];
$bookings = [ // newest first
    ['id' => 30, 'user_id' => 1, 'court_id' => 9, 'sub_court_id' => null, 'start_time' => '2026-11-29 19:00:00', 'end_time' => '2026-11-29 20:00:00', 'court_name' => 'Kick Arena', 'court_type' => 'turf'], // future
    ['id' => 20, 'user_id' => 1, 'court_id' => 9, 'sub_court_id' => 4, 'start_time' => '2026-11-18 19:00:00', 'end_time' => '2026-11-18 20:00:00', 'court_name' => 'Kick Arena', 'court_type' => 'turf'],
    ['id' => 15, 'user_id' => 3, 'court_id' => 5, 'sub_court_id' => null, 'start_time' => '2026-11-10 07:00:00', 'end_time' => '2026-11-10 08:00:00', 'court_name' => 'Ace', 'court_type' => 'tennis'],
    ['id' => 10, 'user_id' => 1, 'court_id' => 9, 'sub_court_id' => 4, 'start_time' => '2026-11-11 19:00:00', 'end_time' => '2026-11-11 20:00:00', 'court_name' => 'Kick Arena', 'court_type' => 'turf'],
    ['id' => 5, 'user_id' => 4, 'court_id' => 5, 'sub_court_id' => null, 'start_time' => '2026-11-01 07:00:00', 'end_time' => '2026-11-01 08:00:00'], // I'm not in it
];
$players = [30 => [4], 20 => [2, 3], 15 => [1], 10 => [2], 5 => [2]];
$crew = PlayerCrew::build($bookings, $players, $people, $me, $now);

check(array_column($crew['mates'], 'name') === ['Arjun', 'Ravi'], 'mates ranked by games together; future-only mates and strangers left out');
check($crew['mates'][0]['games'] === 2 && $crew['mates'][0]['last_played'] === '2026-11-18 19:00:00', 'games and last played counted');
check($crew['mates'][1]['games'] === 2, 'booked by them, played by me counts too');
check(!array_key_exists('phone', $crew['mates'][0]), 'no phone numbers');
check($crew['rebook'] !== null && $crew['rebook']['player_ids'] === [2, 3], 'rebook uses the latest game I booked with others');
check($crew['rebook']['start_time'] === '2026-12-02 19:00:00' && $crew['rebook']['sub_court_id'] === 4, 'rebook moves to next Wednesday, same space');
check($crew['rebook']['player_names'] === ['Arjun', 'Ravi'], 'rebook names the squad');
check(PlayerCrew::build([], [], $people, $me, $now) === ['mates' => [], 'rebook' => null], 'no games, no crew');

exit($failed ? 1 : 0);
