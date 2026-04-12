-- Migration 003: Membership plans
CREATE TABLE IF NOT EXISTS plans (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    court_id      INT           NOT NULL,
    name          VARCHAR(255)  NOT NULL,
    description   TEXT,
    duration_days INT           NOT NULL,
    price         DECIMAL(10,2) NOT NULL,
    created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
);
