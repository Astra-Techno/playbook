-- Additive. Organizer messages for one event. Delivery uses user_notifications.
CREATE TABLE IF NOT EXISTS tournament_announcements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tournament_id INT NOT NULL,
    title VARCHAR(120) NOT NULL,
    body VARCHAR(500) NOT NULL,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_announcement_event (tournament_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
