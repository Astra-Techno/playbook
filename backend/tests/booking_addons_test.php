<?php

require_once __DIR__ . '/../src/BookingAddons.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) { echo "ok  $message\n"; return; }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}
function rejects(callable $fn, string $message): void
{
    try { $fn(); check(false, $message); } catch (InvalidArgumentException $e) { check(true, $message); }
}

$items = [
    ['id' => 1, 'name' => 'Bat', 'status' => 'active', 'rental_rupees' => 50, 'deposit_rupees' => 500],
    ['id' => 2, 'name' => 'Bibs', 'status' => 'active', 'rental_rupees' => 20, 'deposit_rupees' => 0],
    ['id' => 3, 'name' => 'Old balls', 'status' => 'retired', 'rental_rupees' => 10, 'deposit_rupees' => 0],
    ['id' => 4, 'name' => 'Cones', 'status' => 'active', 'rental_rupees' => 0, 'deposit_rupees' => 0],
];
$free = [1 => 2, 2 => 10, 3 => 5, 4 => 5];

$none = BookingAddons::price($items, null, $free);
check($none === ['lines' => [], 'paise' => 0], 'no add-ons costs nothing');

$q = BookingAddons::price($items, [['item_id' => 1, 'quantity' => 1], ['item_id' => 2, 'quantity' => 5], ['item_id' => 1, 'quantity' => 1]], $free);
check($q['paise'] === (2 * 50 + 5 * 20) * 100, 'rental price is quantity × rate, in paise');
check(count($q['lines']) === 2 && $q['lines'][0]['quantity'] === 2, 'repeated items merge into one line');
check($q['lines'][0]['deposit_rupees'] === 500, 'deposit is carried but not charged');

rejects(fn () => BookingAddons::price($items, [['item_id' => 1, 'quantity' => 3]], $free), 'cannot book more than is free');
rejects(fn () => BookingAddons::price($items, [['item_id' => 3, 'quantity' => 1]], $free), 'retired items are refused');
rejects(fn () => BookingAddons::price($items, [['item_id' => 4, 'quantity' => 1]], $free), 'items without a rental price are not add-ons');
rejects(fn () => BookingAddons::price($items, [['item_id' => 99, 'quantity' => 1]], $free), 'another venue\'s item is refused');
rejects(fn () => BookingAddons::price($items, [['item_id' => 2, 'quantity' => 0]], $free), 'zero quantity is refused');
rejects(fn () => BookingAddons::price($items, [['item_id' => 2, 'quantity' => -4]], $free), 'negative quantity cannot discount the booking');
rejects(fn () => BookingAddons::price($items, ['item_id' => 2], $free), 'a non-list is refused');
rejects(fn () => BookingAddons::price($items, array_fill(0, 11, ['item_id' => 2, 'quantity' => 1]), $free), 'at most ten lines');

exit($failed ? 1 : 0);
