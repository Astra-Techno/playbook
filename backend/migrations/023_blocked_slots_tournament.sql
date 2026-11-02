-- Additive. Links a venue closure to the event that created it.
ALTER TABLE blocked_slots
    ADD COLUMN tournament_id INT NULL DEFAULT NULL,
    ADD INDEX idx_block_tournament (tournament_id);
