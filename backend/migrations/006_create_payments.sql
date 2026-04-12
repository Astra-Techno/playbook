-- Migration 006: Payments
CREATE TABLE IF NOT EXISTS payments (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT,
    subscription_id INT,
    amount          DECIMAL(10,2) NOT NULL,
    transaction_id  VARCHAR(255),
    status          ENUM('pending', 'success', 'failed') DEFAULT 'pending',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id)      REFERENCES bookings(id)           ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES user_subscriptions(id) ON DELETE SET NULL
);
