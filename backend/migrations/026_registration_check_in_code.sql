-- Additive. Door code for a confirmed entry. The entry state stays confirmed.
-- The API may already have added this column before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE tournament_registrations ADD COLUMN check_in_code VARCHAR(8) NULL DEFAULT NULL, ADD UNIQUE KEY uq_registration_code (check_in_code)',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tournament_registrations'
    AND COLUMN_NAME = 'check_in_code'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
