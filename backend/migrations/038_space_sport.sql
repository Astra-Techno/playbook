-- Additive. Owner batch A: each space (sub-court) can carry its own sport, so a complex with a turf,
-- shuttle courts and a gym is found under each sport. NULL means "same as the venue".
-- The API also adds this column itself, so it runs only when the column is still missing.
SET @sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sub_courts') = 1
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sub_courts' AND COLUMN_NAME = 'sport') = 0,
    'ALTER TABLE sub_courts ADD COLUMN sport VARCHAR(30) NULL DEFAULT NULL, ADD INDEX idx_sub_court_sport (sport)',
    'SET @kocourt_skip = 1'
  )
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
