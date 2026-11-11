<?php

require_once __DIR__ . '/../EquipmentRental.php';

class EquipmentController
{
    public function index(int $courtId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $this->ensure($db);
        if (!$this->owns($db, $courtId, $authUser)) {
            return;
        }
        $stmt = $db->prepare('
            SELECT id, name, quantity_on_hand, deposit_rupees, status
            FROM equipment_items
            WHERE court_id = ?
            ORDER BY id DESC
            LIMIT 50
        ');
        $stmt->execute([$courtId]);
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $open = [];
        if ($items) {
            $rentals = $db->prepare("
                SELECT r.id, r.item_id, r.display_name, r.quantity, r.deposit_rupees, r.deposit_status, r.state
                FROM equipment_rentals r
                INNER JOIN equipment_items i ON i.id = r.item_id
                WHERE i.court_id = ? AND r.state = 'out'
                ORDER BY r.id
            ");
            $rentals->execute([$courtId]);
            foreach ($rentals->fetchAll(PDO::FETCH_ASSOC) as $rental) {
                $open[(int)$rental['item_id']][] = [
                    'id' => (int)$rental['id'],
                    'display_name' => (string)$rental['display_name'],
                    'quantity' => (int)$rental['quantity'],
                    'deposit_rupees' => (int)$rental['deposit_rupees'],
                    'deposit_status' => (string)$rental['deposit_status'],
                    'state' => (string)$rental['state'],
                ];
            }
        }
        $rows = [];
        foreach ($items as $item) {
            $rentals = $open[(int)$item['id']] ?? [];
            $out = 0;
            foreach ($rentals as $rental) {
                $out += $rental['quantity'];
            }
            $item['out_quantity'] = $out;
            $item['rentals'] = $rentals;
            $rows[] = $item;
        }
        echo json_encode(['items' => $rows]);
    }

    public function create(int $courtId): void
    {
        $authUser = Auth::require();
        $userId = (int)$authUser['id'];
        $db = Database::getConnection();
        $this->ensure($db);
        if (!$this->owns($db, $courtId, $authUser)) {
            return;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $plan = EquipmentRental::catalog(
            (string)($input['name'] ?? ''),
            $this->whole($input['quantity_on_hand'] ?? null) ?? 0,
            $this->whole($input['deposit_rupees'] ?? null) ?? -1
        );
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $ins = $db->prepare('
            INSERT INTO equipment_items (court_id, name, quantity_on_hand, deposit_rupees, status, created_by)
            VALUES (?, ?, ?, ?, \'active\', ?)
        ');
        $ins->execute([$courtId, $plan['name'], $plan['quantity'], $plan['deposit_rupees'], $userId]);
        echo json_encode(['id' => (int)$db->lastInsertId(), 'status' => 'active']);
    }

    public function lend(int $itemId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $db->beginTransaction();
        try {
            $stmt = $db->prepare('SELECT id, court_id, status, quantity_on_hand, deposit_rupees FROM equipment_items WHERE id = ? FOR UPDATE');
            $stmt->execute([$itemId]);
            $item = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$item) {
                $db->rollBack();
                http_response_code(404);
                echo json_encode(['message' => 'Item not found']);
                return;
            }
            if (!$this->owns($db, (int)$item['court_id'], $authUser)) {
                $db->rollBack();
                return;
            }
            $outStmt = $db->prepare("SELECT COALESCE(SUM(quantity), 0) FROM equipment_rentals WHERE item_id = ? AND state = 'out'");
            $outStmt->execute([$itemId]);
            $plan = EquipmentRental::lend(
                (string)$item['status'],
                (int)$item['quantity_on_hand'],
                (int)$outStmt->fetchColumn(),
                $this->whole($input['quantity'] ?? null) ?? 0,
                (string)($input['display_name'] ?? '')
            );
            if (!$plan['ok']) {
                $db->rollBack();
                http_response_code(422);
                echo json_encode(['message' => $plan['message']]);
                return;
            }
            $ins = $db->prepare("
                INSERT INTO equipment_rentals (item_id, display_name, quantity, deposit_rupees, deposit_status, state)
                VALUES (?, ?, ?, ?, 'held', 'out')
            ");
            $ins->execute([$itemId, $plan['name'], $plan['quantity'], (int)$item['deposit_rupees']]);
            $db->commit();
            echo json_encode([
                'id' => (int)$db->lastInsertId(),
                'state' => 'out',
                'deposit_status' => 'held',
            ]);
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            http_response_code(503);
            echo json_encode(['message' => 'The rental could not be saved.']);
        }
    }

    public function giveBack(int $rentalId): void
    {
        $authUser = Auth::require();
        $db = Database::getConnection();
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $stmt = $db->prepare('
            SELECT r.id, r.state, i.court_id
            FROM equipment_rentals r
            INNER JOIN equipment_items i ON i.id = r.item_id
            WHERE r.id = ?
        ');
        $stmt->execute([$rentalId]);
        $rental = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$rental) {
            http_response_code(404);
            echo json_encode(['message' => 'Rental not found']);
            return;
        }
        if (!$this->owns($db, (int)$rental['court_id'], $authUser)) {
            return;
        }
        $plan = EquipmentRental::giveBack((string)$rental['state'], (string)($input['deposit_status'] ?? ''));
        if (!$plan['ok']) {
            http_response_code(422);
            echo json_encode(['message' => $plan['message']]);
            return;
        }
        $upd = $db->prepare("UPDATE equipment_rentals SET state = 'returned', deposit_status = ? WHERE id = ? AND state = 'out'");
        $upd->execute([$plan['deposit_status'], $rentalId]);
        if (!$upd->rowCount()) {
            http_response_code(409);
            echo json_encode(['message' => 'This rental is already closed.']);
            return;
        }
        echo json_encode(['state' => 'returned', 'deposit_status' => $plan['deposit_status']]);
    }

    /** @param array<string,mixed> $authUser */
    private function owns(PDO $db, int $courtId, array $authUser): bool
    {
        $court = $db->prepare('SELECT id, owner_id FROM courts WHERE id = ?');
        $court->execute([$courtId]);
        $venue = $court->fetch(PDO::FETCH_ASSOC);
        if (!$venue) {
            http_response_code(404);
            echo json_encode(['message' => 'Venue not found']);
            return false;
        }
        $allowed = ($authUser['role'] ?? '') === 'admin' || (int)$venue['owner_id'] === (int)$authUser['id'];
        if (!$allowed) {
            http_response_code(403);
            echo json_encode(['message' => 'Forbidden']);
            return false;
        }
        return true;
    }

    private function ensure(PDO $db): void
    {
        $db->exec("
            CREATE TABLE IF NOT EXISTS equipment_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                court_id INT NOT NULL,
                name VARCHAR(80) NOT NULL,
                quantity_on_hand INT NOT NULL,
                deposit_rupees INT NOT NULL DEFAULT 0,
                status VARCHAR(20) NOT NULL DEFAULT 'active',
                created_by INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_equipment_court (court_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        $db->exec("
            CREATE TABLE IF NOT EXISTS equipment_rentals (
                id INT AUTO_INCREMENT PRIMARY KEY,
                item_id INT NOT NULL,
                display_name VARCHAR(80) NOT NULL,
                quantity INT NOT NULL,
                deposit_rupees INT NOT NULL DEFAULT 0,
                deposit_status VARCHAR(20) NOT NULL DEFAULT 'held',
                state VARCHAR(20) NOT NULL DEFAULT 'out',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_rental_item (item_id, state)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
    }

    private function whole(mixed $value): ?int
    {
        if (is_int($value) && $value >= 0) {
            return $value;
        }
        if (is_string($value) && preg_match('/^\d+$/', $value) === 1) {
            return (int)$value;
        }
        return null;
    }
}
