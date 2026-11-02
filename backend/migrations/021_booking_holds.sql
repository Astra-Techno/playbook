-- Additive. Expiring reservations while a booking payment is unfinished.
-- Booking status values are unchanged.
CREATE TABLE IF NOT EXISTS booking_holds (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hold_key VARCHAR(64) NOT NULL,
    user_id INT NOT NULL,
    payment_id INT NULL,
    court_id INT NOT NULL,
    sub_court_id INT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    expires_at DATETIME NOT NULL,
    released_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_hold_key (hold_key),
    INDEX idx_hold_court (court_id, start_time, end_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
