-- Migration 009: Community posts
CREATE TABLE IF NOT EXISTS posts (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT  NOT NULL,
    content    TEXT NOT NULL,
    image_url  VARCHAR(255),
    court_id   INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE,
    FOREIGN KEY (court_id) REFERENCES courts(id)  ON DELETE SET NULL
);
