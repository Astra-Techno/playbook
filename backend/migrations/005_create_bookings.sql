-- Migration 005: Bookings
CREATE TABLE IF NOT EXISTS bookings (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT           NOT NULL,
    court_id       INT           NOT NULL,
    start_time     DATETIME      NOT NULL,
    end_time       DATETIME      NOT NULL,
    type           ENUM('hourly', 'subscription') NOT NULL,
    total_price    DECIMAL(10,2) NOT NULL,
    status         ENUM('pending', 'confirmed', 'cancelled') DEFAULT 'confirmed',
    payment_status ENUM('pending', 'paid', 'failed')         DEFAULT 'pending',
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
    FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
);
