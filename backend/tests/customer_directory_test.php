<?php

require_once __DIR__ . '/../src/CustomerDirectory.php';

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

check(CustomerDirectory::canView(false, true, null) === true, 'the venue owner can open the directory');
check(CustomerDirectory::canView(false, false, 'manager') === true, 'a manager can open the directory');
check(CustomerDirectory::canView(false, false, 'viewer') === false, 'a viewer cannot open the directory');
check(CustomerDirectory::canView(false, false, null) === false, 'another player cannot open the directory');

$row = CustomerDirectory::row([
    'id' => 8,
    'name' => 'Ada',
    'phone' => '9999900000',
    'booking_count' => 3,
    'last_played' => '2026-11-02 18:00:00',
]);
check($row['name'] === 'Ada' && $row['booking_count'] === 3, 'a customer keeps the name and booking count');
check(!array_key_exists('phone', $row), 'a phone number is left off the directory');

$regular = CustomerDirectory::regular([
    'id' => 8,
    'name' => 'Ada',
    'phone' => '9999900000',
    'avatar_url' => null,
    'booking_count' => 2,
]);
check(!array_key_exists('phone', $regular), 'a phone number is left off the public regulars list');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
