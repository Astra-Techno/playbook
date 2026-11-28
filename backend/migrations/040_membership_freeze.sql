-- Additive. Owner batch C: a membership can be frozen (paused); the end date moves out by the frozen days.
-- The API also adds these columns itself on first use.
SET @sql = (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_subscriptions') = 1
      AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_subscriptions' AND COLUMN_NAME = 'frozen_from') = 0,
    'ALTER TABLE user_subscriptions ADD COLUMN frozen_from DATE NULL DEFAULT NULL, ADD COLUMN frozen_until DATE NULL DEFAULT NULL, ADD COLUMN freeze_days_used INT NOT NULL DEFAULT 0',
    'SET @kocourt_skip = 1'
  )
);
PREPARE kocourt_stmt FROM @sql;
EXECUTE kocourt_stmt;
DEALLOCATE PREPARE kocourt_stmt;
