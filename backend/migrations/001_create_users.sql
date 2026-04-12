-- Migration 001: Users table
CREATE TABLE IF NOT EXISTS users (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    email      VARCHAR(255) UNIQUE,
    password   VARCHAR(255),
    phone      VARCHAR(20)  UNIQUE,
    role       ENUM('admin', 'owner', 'player', 'user') DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
