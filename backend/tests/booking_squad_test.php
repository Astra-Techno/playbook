<?php

require_once __DIR__ . '/../src/BookingSquad.php';

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

$booking = ['user_id' => '10', 'owner_id' => 20];

check(BookingSquad::canView($booking, 10, 'user', false, false), 'the booker sees the squad');
check(BookingSquad::canView($booking, 20, 'user', false, false), 'the venue owner sees the squad');
check(BookingSquad::canView($booking, 30, 'user', true, false), 'an added player sees the squad');
check(BookingSquad::canView($booking, 31, 'user', false, true), 'venue staff see the squad');
check(BookingSquad::canView($booking, 99, 'admin', false, false), 'an admin sees the squad');
check(!BookingSquad::canView($booking, 77, 'user', false, false), 'a stranger cannot read the squad');

check(BookingSquad::canInvite($booking, 10, 'user'), 'the booker can add players');
check(!BookingSquad::canInvite($booking, 30, 'user'), 'an added player cannot add more people');
check(!BookingSquad::canInvite($booking, 20, 'user'), 'the venue owner cannot add players to a customer booking');
check(!BookingSquad::canInvite($booking, 77, 'user'), 'a stranger cannot add players');

exit($failed ? 1 : 0);
