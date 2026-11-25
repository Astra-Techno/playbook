-- Additive. Player add-ons at checkout: a rental price per item, and rentals tied to a booking.
-- The API may already have added these columns before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE equipment_items ADD COLUMN rental_rupees INT NOT NULL DEFAULT 0',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipment_items' AND COLUMN_NAME = 'rental_rupees'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;

SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE equipment_rentals ADD COLUMN booking_id INT NULL DEFAULT NULL, ADD COLUMN rental_rupees INT NOT NULL DEFAULT 0, ADD COLUMN reserved_start DATETIME NULL DEFAULT NULL, ADD COLUMN reserved_end DATETIME NULL DEFAULT NULL, ADD INDEX idx_rental_booking (booking_id)',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipment_rentals' AND COLUMN_NAME = 'booking_id'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
