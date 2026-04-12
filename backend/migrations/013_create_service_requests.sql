CREATE TABLE IF NOT EXISTS service_requests (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    place_id   INT  NOT NULL,
    user_id    INT  NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_place_user (place_id, user_id),
    FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
