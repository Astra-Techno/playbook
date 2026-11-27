-- Additive. Matchday phases 2-3: open spots linked to a booking, and who has paid the booker back.
-- Both tables are created by the API on first use, and the API also adds these columns itself,
-- so each change runs only when its table exists and the column is still missing.
SET @sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_requests') = 1
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_requests' AND COLUMN_NAME = 'booking_id') = 0,
    'ALTER TABLE match_requests ADD COLUMN booking_id INT NULL DEFAULT NULL, ADD INDEX idx_match_booking (booking_id)',
    'SET @kocourt_skip = 1'
  )
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;

SET @sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'booking_players') = 1
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'booking_players' AND COLUMN_NAME = 'paid') = 0,
    'ALTER TABLE booking_players ADD COLUMN paid TINYINT(1) NOT NULL DEFAULT 0',
    'SET @kocourt_skip = 1'
  )
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
