<?php

require_once __DIR__ . '/../src/BookingCheckIn.php';

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

$payload = BookingCheckIn::payload(42, 'ABCD2345');
check($payload === 'KOCOURT-CHECKIN:42:ABCD2345', 'the pass payload names the booking and code');
check(BookingCheckIn::parse($payload) === ['id' => 42, 'code' => 'ABCD2345'], 'a scanned pass is read back');
check(BookingCheckIn::parse(' KOCOURT-CHECKIN:42:abcd2345 ') === ['id' => 42, 'code' => 'ABCD2345'], 'case and spaces are forgiven');
check(BookingCheckIn::parse('KOCOURT-CHECKIN:42:ABCD234') === null, 'a short code is refused');
check(BookingCheckIn::parse('KOCOURT-CHECKIN:42:ABCD234O') === null, 'look-alike letters are refused');
check(BookingCheckIn::parse('KOCOURT-CHECKIN:0:ABCD2345') === null, 'booking id must be positive');
check(BookingCheckIn::parse('KOCOURT-CHECKIN:4x:ABCD2345') === null, 'booking id must be a number');
check(BookingCheckIn::parse('https://example.com') === null, 'any other QR is refused');

check(BookingCheckIn::matches('ABCD2345', 'ABCD2345'), 'the stored code matches');
check(!BookingCheckIn::matches('ABCD2345', 'ABCD2346'), 'a wrong code does not match');
check(!BookingCheckIn::matches(null, 'ABCD2345'), 'a booking without a code never matches');

check(BookingCheckIn::canShow(10, 10, false), 'the booker can show the pass');
check(BookingCheckIn::canShow(10, 11, true), 'a squad player can show the pass');
check(!BookingCheckIn::canShow(10, 12, false), 'a stranger cannot fetch the pass code');

exit($failed ? 1 : 0);
