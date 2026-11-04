-- One owner alert per booking arrival. A second refresh finds the same event key.
-- The body stores a name and a time. It does not store a phone number.
-- The API may already have added this column before this file runs.

SET @sql = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE user_notifications ADD COLUMN event_key VARCHAR(80) NULL DEFAULT NULL, ADD UNIQUE KEY uq_user_event_key (user_id, event_key)',
    'SET @kocourt_skip = 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'user_notifications'
    AND COLUMN_NAME = 'event_key'
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
