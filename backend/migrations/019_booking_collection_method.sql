-- Additive. Records how a walk-in price is taken.
-- Online bookings leave this null. payment_status is unchanged.
-- The API may already have added this column before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE bookings ADD COLUMN collection_method VARCHAR(32) NULL DEFAULT NULL',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'collection_method'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
