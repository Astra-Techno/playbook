-- Match rows for an event category. A result is one row per match.
-- Booking status values are unchanged. This does not place a court booking.

CREATE TABLE IF NOT EXISTS tournament_matches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    round_label VARCHAR(40) NOT NULL DEFAULT 'Match',
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_match_category (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_match_participants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT NOT NULL,
    registration_id INT NOT NULL,
    side VARCHAR(10) NOT NULL,
    UNIQUE KEY uq_match_side (match_id, side),
    UNIQUE KEY uq_match_entry (match_id, registration_id),
    INDEX idx_participant_registration (registration_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT NOT NULL,
    winner_registration_id INT NOT NULL,
    home_score INT NOT NULL,
    away_score INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_match_result (match_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
