-- Additive. Owner batch B: members check in at the door with a pass, and each day's visit is counted.
-- The API also creates these itself on first use.
SET @sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_subscriptions') = 1
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_subscriptions' AND COLUMN_NAME = 'check_in_code') = 0,
    'ALTER TABLE user_subscriptions ADD COLUMN check_in_code CHAR(8) NULL DEFAULT NULL, ADD UNIQUE INDEX uq_sub_check_in_code (check_in_code)',
    'SET @kocourt_skip = 1'
  )
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;

CREATE TABLE IF NOT EXISTS member_visits (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    subscription_id INT NOT NULL,
    user_id         INT NOT NULL,
    court_id        INT NOT NULL,
    visit_date      DATE NOT NULL,
    visited_at      DATETIME NOT NULL,
    checked_in_by   INT NULL,
    UNIQUE KEY uq_member_visit_day (subscription_id, visit_date),
    INDEX idx_member_visits_court (court_id, visit_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
