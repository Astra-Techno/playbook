-- Add admin role to users
ALTER TABLE users
    MODIFY COLUMN role ENUM('player','owner','admin') NOT NULL DEFAULT 'player';

-- In-app notifications (venue went live, etc.)
CREATE TABLE IF NOT EXISTS user_notifications (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT          NOT NULL,
    type       VARCHAR(50)  NOT NULL,
    title      VARCHAR(255) NOT NULL,
    body       TEXT,
    court_id   INT          DEFAULT NULL,
    read_at    DATETIME     DEFAULT NULL,
    created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
    FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
