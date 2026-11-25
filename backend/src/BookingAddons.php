<?php

/**
 * Player add-ons at checkout (bat, balls, bibs): the venue's equipment items
 * that have a rental price. The rental is paid online with the slot; the
 * deposit stays a venue-side cash hold, taken when the kit is handed over.
 */
final class BookingAddons
{
    public const MAX_LINES = 10;
    public const MAX_QUANTITY = 20;

    /**
     * Price the requested add-ons against the venue's catalog and free stock.
     *
     * @param list<array{id:int|string,name:string,status:string,rental_rupees:int|string,deposit_rupees:int|string}> $items
     * @param mixed $requested [{item_id, quantity}, ...] straight from the client
     * @param array<int,int> $freeByItem units still free for the booked window
     * @return array{lines:list<array{item_id:int,name:string,quantity:int,rental_rupees:int,deposit_rupees:int}>,paise:int}
     */
    public static function price(array $items, mixed $requested, array $freeByItem): array
    {
        if ($requested === null || $requested === []) return ['lines' => [], 'paise' => 0];
        if (!is_array($requested) || !array_is_list($requested) || count($requested) > self::MAX_LINES) {
            throw new InvalidArgumentException('Choose up to ' . self::MAX_LINES . ' add-ons');
        }
        $byId = [];
        foreach ($items as $item) $byId[(int)$item['id']] = $item;
        $wanted = [];
        foreach ($requested as $line) {
            $id = (int)($line['item_id'] ?? 0);
            $qty = (int)($line['quantity'] ?? 0);
            $item = $byId[$id] ?? null;
            if (!$item || $item['status'] !== 'active' || (int)$item['rental_rupees'] <= 0) {
                throw new InvalidArgumentException('An add-on is no longer offered at this venue');
            }
            if ($qty < 1 || $qty > self::MAX_QUANTITY) throw new InvalidArgumentException('Add-on quantity must be 1 to ' . self::MAX_QUANTITY);
            $wanted[$id] = ($wanted[$id] ?? 0) + $qty;
        }
        $lines = [];
        $paise = 0;
        foreach ($wanted as $id => $qty) {
            $item = $byId[$id];
            if ($qty > ($freeByItem[$id] ?? 0)) {
                throw new InvalidArgumentException("Only " . max(0, $freeByItem[$id] ?? 0) . " {$item['name']} left for this time");
            }
            $lines[] = [
                'item_id' => $id,
                'name' => (string)$item['name'],
                'quantity' => $qty,
                'rental_rupees' => (int)$item['rental_rupees'],
                'deposit_rupees' => (int)$item['deposit_rupees'],
            ];
            $paise += $qty * (int)$item['rental_rupees'] * 100;
        }
        return ['lines' => $lines, 'paise' => $paise];
    }

    /** Units free for [$start, $end): on hand minus kit reserved for overlapping live bookings. */
    public static function free(PDO $db, int $courtId, string $start, string $end): array
    {
        // shortcut: ad-hoc counter lends (state 'out', no booking) are not counted; they are short and same-session. Count them if venues lend kit for long.
        $stmt = $db->prepare("
            SELECT i.id, i.quantity_on_hand - COALESCE((
                SELECT SUM(r.quantity) FROM equipment_rentals r
                INNER JOIN bookings b ON b.id = r.booking_id
                WHERE r.item_id = i.id AND r.state IN ('reserved', 'out') AND b.status <> 'cancelled'
                  AND r.reserved_start < ? AND r.reserved_end > ?
            ), 0) AS free
            FROM equipment_items i WHERE i.court_id = ?
        ");
        $stmt->execute([$end, $start, $courtId]);
        $free = [];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) $free[(int)$row['id']] = (int)$row['free'];
        return $free;
    }

    /** @return list<array<string,mixed>> the venue's rentable items */
    public static function catalog(PDO $db, int $courtId): array
    {
        $stmt = $db->prepare("SELECT id, name, status, rental_rupees, deposit_rupees FROM equipment_items WHERE court_id = ? AND status = 'active' AND rental_rupees > 0 ORDER BY name");
        $stmt->execute([$courtId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /** Price for checkout, from the database. */
    public static function quote(PDO $db, int $courtId, mixed $requested, string $start, string $end): array
    {
        if ($requested === null || $requested === []) return ['lines' => [], 'paise' => 0];
        return self::price(self::catalog($db, $courtId), $requested, self::free($db, $courtId, $start, $end));
    }

    /**
     * After payment: reserve the kit on the booking. Runs under the court's SlotLock.
     * Returns false (nothing saved) if another checkout took the stock meanwhile.
     */
    public static function reserve(PDO $db, int $courtId, int $bookingId, array $lines, string $start, string $end): bool
    {
        $free = self::free($db, $courtId, $start, $end);
        foreach ($lines as $line) {
            if ((int)$line['quantity'] > ($free[(int)$line['item_id']] ?? 0)) return false;
        }
        $ins = $db->prepare("
            INSERT INTO equipment_rentals (item_id, booking_id, display_name, quantity, deposit_rupees, rental_rupees, deposit_status, state, reserved_start, reserved_end)
            SELECT ?, b.id, COALESCE(u.name, 'Player'), ?, ?, ?, 'pending', 'reserved', ?, ?
            FROM bookings b LEFT JOIN users u ON u.id = b.user_id WHERE b.id = ?
        ");
        foreach ($lines as $line) {
            $ins->execute([(int)$line['item_id'], (int)$line['quantity'], (int)$line['deposit_rupees'], (int)$line['rental_rupees'], $start, $end, $bookingId]);
        }
        return true;
    }

    /** Check-in hands the reserved kit over: it is now out, deposit held at the counter. */
    public static function handOver(PDO $db, int $bookingId): void
    {
        $db->prepare("UPDATE equipment_rentals SET state = 'out', deposit_status = 'held' WHERE booking_id = ? AND state = 'reserved'")
            ->execute([$bookingId]);
    }

    /** @return list<array<string,mixed>> add-ons booked with a booking, for its detail screens */
    public static function forBooking(PDO $db, int $bookingId): array
    {
        $stmt = $db->prepare("
            SELECT r.id, i.name, r.quantity, r.rental_rupees, r.deposit_rupees, r.state, r.deposit_status
            FROM equipment_rentals r INNER JOIN equipment_items i ON i.id = r.item_id
            WHERE r.booking_id = ? ORDER BY r.id
        ");
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
