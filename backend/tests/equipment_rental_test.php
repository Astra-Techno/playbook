<?php

require_once __DIR__ . '/../src/EquipmentRental.php';

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

$item = EquipmentRental::catalog(' Racket ', 10, 200);
check($item['ok'] === true && $item['name'] === 'Racket' && $item['deposit_rupees'] === 200, 'an item keeps a quantity and a deposit');
check(EquipmentRental::catalog(' ', 10, 0)['ok'] === false, 'an item needs a name');
check(EquipmentRental::catalog('Ball', 0, 0)['ok'] === false, 'quantity starts at one');
check(EquipmentRental::catalog('Ball', 10, -1)['ok'] === false, 'a deposit cannot be negative');

$lent = EquipmentRental::lend('active', 10, 8, 2, ' Bo ');
check($lent['ok'] === true && $lent['name'] === 'Bo' && $lent['quantity'] === 2, 'a player can take the remaining quantity');
check(EquipmentRental::lend('active', 10, 8, 3, 'Cy')['ok'] === false, 'a rental cannot exceed what is in');
check(EquipmentRental::lend('retired', 10, 0, 1, 'Cy')['ok'] === false, 'a retired item cannot be rented');
check(EquipmentRental::lend('active', 10, 0, 1, ' ')['ok'] === false, 'a rental needs a player name');

$back = EquipmentRental::giveBack('out', 'returned');
check($back['ok'] === true && $back['deposit_status'] === 'returned', 'a deposit can be marked returned');
check(EquipmentRental::giveBack('out', 'kept')['deposit_status'] === 'kept', 'a deposit can be marked kept');
check(EquipmentRental::giveBack('returned', 'returned')['ok'] === false, 'a second return is refused');
check(EquipmentRental::giveBack('out', 'held')['ok'] === false, 'closing a rental needs returned or kept');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
