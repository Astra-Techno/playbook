-- Migration 007: Reviews
CREATE TABLE IF NOT EXISTS reviews (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    court_id   INT        NOT NULL,
    user_id    INT        NOT NULL,
    booking_id INT        NOT NULL,
    rating     TINYINT(1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_review (booking_id),
    FOREIGN KEY (court_id)   REFERENCES courts(id)   ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);
