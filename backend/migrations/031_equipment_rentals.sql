-- Desk equipment at one venue. A rental is a quantity and a deposit status.
-- It does not insert a booking or a payment.

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
