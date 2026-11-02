-- Additive. Shared event tables for the customer app and the Partner app.
-- Names follow the customer plan. Booking status values are unchanged.
-- booking_holds remains the checkout reserve. Court time is still blocked_slots.

CREATE TABLE IF NOT EXISTS tournaments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(160) NOT NULL,
    sport VARCHAR(60) NOT NULL,
    court_id INT NULL,
    start_time DATETIME NULL,
    end_time DATETIME NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Kolkata',
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    visibility VARCHAR(20) NOT NULL DEFAULT 'private',
    source_type VARCHAR(20) NOT NULL DEFAULT 'internal',
    external_source_url VARCHAR(500) NULL,
    registration_deadline DATETIME NULL,
    policies TEXT NULL,
    cover_url VARCHAR(500) NULL,
    verified_at DATETIME NULL,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tournament_court (court_id),
    INDEX idx_tournament_creator (created_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_organizers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tournament_id INT NOT NULL,
    user_id INT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'organizer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_tournament_organizer (tournament_id, user_id),
    INDEX idx_organizer_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tournament_id INT NOT NULL,
    name VARCHAR(120) NOT NULL,
    format VARCHAR(20) NOT NULL DEFAULT 'singles',
    eligibility VARCHAR(255) NULL,
    fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    capacity INT NOT NULL DEFAULT 0,
    waitlist TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category_tournament (tournament_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_registrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    captain_user_id INT NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'pending',
    fee_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    payment_id INT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_registration_idem (idempotency_key),
    INDEX idx_registration_category (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_registration_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    registration_id INT NOT NULL,
    user_id INT NULL,
    display_name VARCHAR(120) NULL,
    confirm_state VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_registration (registration_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_capacity_holds (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    request_key VARCHAR(64) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    expires_at DATETIME NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_capacity_request (request_key),
    INDEX idx_capacity_category (category_id, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
