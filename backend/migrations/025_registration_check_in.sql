-- Additive. Arrival time for a confirmed entry. The entry state stays confirmed.
ALTER TABLE tournament_registrations
    ADD COLUMN checked_in_at DATETIME NULL DEFAULT NULL;
