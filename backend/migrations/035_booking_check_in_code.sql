-- Additive. QR door code for a confirmed booking, created when the pass first asks for it.
-- The API may already have added this column before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE bookings ADD COLUMN check_in_code VARCHAR(8) NULL DEFAULT NULL, ADD UNIQUE KEY uq_booking_check_in_code (check_in_code)',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'check_in_code'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
