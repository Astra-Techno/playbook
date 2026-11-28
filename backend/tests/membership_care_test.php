<?php

require_once __DIR__ . '/../src/MembershipCare.php';

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

$today = '2026-11-28';

$f = MembershipCare::freeze('active', '2026-12-16', null, 0, 14, $today);
check($f['ok'] && $f['from'] === '2026-11-28' && $f['until'] === '2026-12-11', 'a 14-day freeze runs today to 11 Dec');
check($f['end'] === '2026-12-30' && $f['used'] === 14, 'the end date moves out by 14 days');
check(!MembershipCare::freeze('active', '2026-12-16', '2026-12-01', 0, 7, $today)['ok'], 'cannot freeze twice at once');
check(MembershipCare::freeze('active', '2026-12-16', '2026-11-20', 10, 7, $today)['ok'], 'a past freeze does not block a new one');
check(!MembershipCare::freeze('active', '2026-12-16', null, 55, 7, $today)['ok'], 'at most 60 freeze days per membership');
check(str_contains(MembershipCare::freeze('active', '2026-12-16', null, 55, 7, $today)['message'], 'Only 5'), 'says how many days are left');
check(!MembershipCare::freeze('active', '2026-12-16', null, 0, 0, $today)['ok'], 'zero days is refused');
check(!MembershipCare::freeze('active', '2026-12-16', null, 0, 31, $today)['ok'], 'over 30 days at once is refused');
check(!MembershipCare::freeze('active', '2026-11-27', null, 0, 7, $today)['ok'], 'an ended membership cannot be frozen');
check(!MembershipCare::freeze('cancelled', '2026-12-16', null, 0, 7, $today)['ok'], 'a cancelled membership cannot be frozen');

check(MembershipCare::isFrozen('2026-11-28', '2026-12-11', '2026-12-11'), 'frozen on the last frozen day');
check(!MembershipCare::isFrozen('2026-11-28', '2026-12-11', '2026-12-12'), 'not frozen after it ends');
check(!MembershipCare::isFrozen(null, null, $today), 'no freeze dates means not frozen');

$u = MembershipCare::unfreeze('2026-11-20', '2026-12-03', '2026-12-30', 14, $today);
check($u['ok'] && $u['until'] === '2026-11-27' && $u['from'] === '2026-11-20', 'ending early keeps the days already frozen');
check($u['end'] === '2026-12-24' && $u['used'] === 8, '6 unused days (28 Nov to 3 Dec) go back');
$same = MembershipCare::unfreeze('2026-11-28', '2026-12-11', '2026-12-30', 14, $today);
check($same['ok'] && $same['from'] === null && $same['until'] === null && $same['end'] === '2026-12-16' && $same['used'] === 0, 'undoing a freeze the same day restores everything');
check(!MembershipCare::unfreeze(null, null, '2026-12-16', 0, $today)['ok'], 'cannot end a freeze that is not on');

check(MembershipCare::reminder('Iron House', '2026-11-28', $today)['title'] === 'Your Iron House membership ends today', 'last day says today');
check(MembershipCare::reminder('Iron House', '2026-11-29', $today)['title'] === 'Your Iron House membership ends tomorrow', 'one more day says tomorrow');
check(MembershipCare::reminder('Iron House', '2026-12-02', $today)['kind'] === 'renew', 'within a week is a renewal reminder');
check(MembershipCare::reminder('Iron House', '2026-12-16', $today)['kind'] === 'quiet', 'further out is a we-miss-you note');
check(str_contains(MembershipCare::reminder('Iron House', '2026-12-16', $today)['body'], '16 Dec'), 'it names the end date');

check(MembershipCare::autoReminderDue('2026-11-30', $today), 'auto reminder 3 days before');
check(MembershipCare::autoReminderDue('2026-11-28', $today), 'auto reminder on the last day');
check(!MembershipCare::autoReminderDue('2026-11-29', $today), 'no auto reminder 2 days before');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
