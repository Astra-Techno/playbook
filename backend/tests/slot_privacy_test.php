<?php

require_once __DIR__ . '/../src/SlotPrivacy.php';

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

$row = [
    'id' => 9, 'user_id' => 42, 'guest_name' => 'Karthik', 'guest_phone' => '9876543210',
    'total_price' => '300.00', 'check_in_code' => 'ABCD2345', 'notes' => 'birthday',
    'sub_court_id' => 3, 'start_time' => '2026-11-25 18:00:00', 'end_time' => '2026-11-25 19:00:00', 'status' => 'confirmed',
];
$public = SlotPrivacy::publicRow($row);

check(array_keys($public) === ['sub_court_id', 'start_time', 'end_time', 'status'], 'only the grid fields are returned');
check($public['start_time'] === '2026-11-25 18:00:00' && $public['sub_court_id'] === 3, 'times and space are kept');
foreach (['user_id', 'guest_name', 'guest_phone', 'total_price', 'check_in_code', 'notes', 'id'] as $hidden) {
    check(!array_key_exists($hidden, $public), "$hidden is not exposed");
}
check(SlotPrivacy::publicRow(['start_time' => 'x'])['sub_court_id'] === null, 'missing fields come back as null');

exit($failed ? 1 : 0);
