-- Additive. Approval on a category, and an optional sponsor name on the event.
ALTER TABLE tournament_categories
    ADD COLUMN approval TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE tournaments
    ADD COLUMN sponsor_name VARCHAR(120) NULL DEFAULT NULL;
