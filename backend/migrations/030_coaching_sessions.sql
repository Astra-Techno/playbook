-- A coaching class at one venue. Court time is a coaching block, not a booking.
-- Instructor is a name on the session. There is no coach marketplace.

CREATE TABLE IF NOT EXISTS coaching_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    court_id INT NOT NULL,
    sub_court_id INT NULL,
    title VARCHAR(120) NOT NULL,
    instructor_name VARCHAR(80) NOT NULL,
    capacity INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_coaching_court (court_id, start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS coaching_enrollments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    user_id INT NULL,
    display_name VARCHAR(80) NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'enrolled',
    attendance VARCHAR(20) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_enrollment_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
