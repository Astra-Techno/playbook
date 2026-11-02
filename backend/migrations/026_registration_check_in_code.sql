-- Additive. Door code for a confirmed entry. The entry state stays confirmed.
ALTER TABLE tournament_registrations
    ADD COLUMN check_in_code VARCHAR(8) NULL DEFAULT NULL,
    ADD UNIQUE KEY uq_registration_code (check_in_code);
