<?php

require_once __DIR__ . '/../src/MemberCheckIn.php';

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

check(MemberCheckIn::payload(12, 'ABCD2345') === 'KOCOURT-MEMBER:12:ABCD2345', 'payload format');
check(MemberCheckIn::parse('KOCOURT-MEMBER:12:abcd2345') === ['id' => 12, 'code' => 'ABCD2345'], 'parse upper-cases the code');
check(MemberCheckIn::parse('KOCOURT-CHECKIN:12:ABCD2345') === null, 'a booking pass is not a member pass');
check(MemberCheckIn::parse('KOCOURT-MEMBER:0:ABCD2345') === null, 'id must be positive');
check(MemberCheckIn::parse('KOCOURT-MEMBER:12:ABCD234') === null, 'code must be 8 characters');
check(MemberCheckIn::parse('KOCOURT-MEMBER:12:ABCD2345:x') === null, 'extra parts are refused');

check(MemberCheckIn::decide('active', '2026-11-01', '2026-11-30', '2026-11-28')['ok'] === true, 'active member inside dates comes in');
check(MemberCheckIn::decide('active', '2026-11-01', '2026-11-30', '2026-11-30')['ok'] === true, 'the last day still counts');
check(MemberCheckIn::decide('active', '2026-11-01 00:00:00', '2026-11-27', '2026-11-28')['ok'] === false, 'ended yesterday is refused');
check(MemberCheckIn::decide('active', '2026-12-01', '2026-12-30', '2026-11-28')['ok'] === false, 'not started yet is refused');
check(MemberCheckIn::decide('cancelled', '2026-11-01', '2026-11-30', '2026-11-28')['ok'] === false, 'cancelled is refused');
check(str_contains(MemberCheckIn::decide('active', '2026-11-01', '2026-11-27', '2026-11-28')['message'], 'Renew'), 'an ended plan points to renewal');

check(MemberCheckIn::daysLeft('2026-11-30', '2026-11-28') === 3, 'days left counts today');
check(MemberCheckIn::daysLeft('2026-11-28', '2026-11-28') === 1, 'last day leaves one');
check(MemberCheckIn::daysLeft('2026-11-27', '2026-11-28') === 0, 'ended leaves zero');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
