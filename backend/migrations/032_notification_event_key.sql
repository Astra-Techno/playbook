-- One owner alert per booking arrival. A second refresh finds the same event key.
-- The body stores a name and a time. It does not store a phone number.

ALTER TABLE user_notifications
    ADD COLUMN event_key VARCHAR(80) NULL DEFAULT NULL,
    ADD UNIQUE KEY uq_user_event_key (user_id, event_key);
