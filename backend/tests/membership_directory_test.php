<?php

require_once __DIR__ . '/../src/MembershipDirectory.php';

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

$row = MembershipDirectory::row([
    'id' => 4,
    'user_id' => 9,
    'user_name' => 'Ada',
    'user_phone' => '9999900000',
    'plan_name' => 'Evening',
    'slot_type' => 'evening',
    'status' => 'active',
    'start_date' => '2026-11-01',
    'end_date' => '2026-12-01',
]);
check($row['user_name'] === 'Ada' && $row['slot_type'] === 'evening', 'a member keeps the name and peak window');
check(!array_key_exists('user_phone', $row), 'a phone number is left off the owner list');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
