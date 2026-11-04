-- Additive. Links a venue closure to the event that created it.
-- The API may already have added this column before this file runs.
SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE blocked_slots ADD COLUMN tournament_id INT NULL DEFAULT NULL, ADD INDEX idx_block_tournament (tournament_id)',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'blocked_slots'
    AND COLUMN_NAME = 'tournament_id'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
