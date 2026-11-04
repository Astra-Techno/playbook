-- Additive. Arrival on a booking. Status values are unchanged.
-- The API may already have added this column before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE bookings ADD COLUMN attendance VARCHAR(20) NULL DEFAULT NULL',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'attendance'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
