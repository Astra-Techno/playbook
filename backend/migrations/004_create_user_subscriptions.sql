-- Migration 004: User subscriptions
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT  NOT NULL,
    plan_id    INT  NOT NULL,
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    status     ENUM('active', 'expired', 'cancelled') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES plans(id)  ON DELETE CASCADE
);
