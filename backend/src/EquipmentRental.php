<?php

/** A venue rental. Quantity and deposit stay off bookings and payments. */
final class EquipmentRental
{
    /** @return array{ok:bool,message?:string,name?:string,quantity?:int,deposit_rupees?:int} */
    public static function catalog(string $name, int $quantity, int $depositRupees): array
    {
        $name = trim($name);
        if ($name === '' || strlen($name) > 80) {
            return ['ok' => false, 'message' => 'Add an item name within 80 characters.'];
        }
        if ($quantity < 1 || $quantity > 200) {
            return ['ok' => false, 'message' => 'Quantity must be from 1 to 200.'];
        }
        if ($depositRupees < 0 || $depositRupees > 50000) {
            return ['ok' => false, 'message' => 'Deposit must be from 0 to 50000 rupees.'];
        }
        return [
            'ok' => true,
            'name' => $name,
            'quantity' => $quantity,
            'deposit_rupees' => $depositRupees,
        ];
    }

    /** @return array{ok:bool,message?:string,name?:string,quantity?:int} */
    public static function lend(string $itemStatus, int $onHand, int $outNow, int $quantity, string $name): array
    {
        if ($itemStatus !== 'active') {
            return ['ok' => false, 'message' => 'This item is not available to rent.'];
        }
        $name = trim($name);
        if ($name === '' || strlen($name) > 80) {
            return ['ok' => false, 'message' => 'Add the player name within 80 characters.'];
        }
        if ($quantity < 1) {
            return ['ok' => false, 'message' => 'Rent at least one.'];
        }
        if ($outNow + $quantity > $onHand) {
            return ['ok' => false, 'message' => 'Not enough of this item is in.'];
        }
        return ['ok' => true, 'name' => $name, 'quantity' => $quantity];
    }

    /** @return array{ok:bool,message?:string,state?:string,deposit_status?:string} */
    public static function giveBack(string $rentalState, string $depositStatus): array
    {
        if ($rentalState !== 'out') {
            return ['ok' => false, 'message' => 'This rental is already closed.'];
        }
        if ($depositStatus !== 'returned' && $depositStatus !== 'kept') {
            return ['ok' => false, 'message' => 'Mark the deposit returned or kept.'];
        }
        return ['ok' => true, 'state' => 'returned', 'deposit_status' => $depositStatus];
    }
}
