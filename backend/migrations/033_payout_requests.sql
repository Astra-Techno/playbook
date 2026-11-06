-- An owner can ask for a manual transfer. This row is not a payout.
CREATE TABLE IF NOT EXISTS payout_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    note VARCHAR(200) DEFAULT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'requested',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_payout_request_owner (owner_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
