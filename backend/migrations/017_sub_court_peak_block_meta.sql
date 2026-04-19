-- v15: per-space peak members override; block category + annual recurrence
ALTER TABLE sub_courts
    ADD COLUMN peak_members_override TINYINT(1) NULL DEFAULT NULL
    COMMENT 'NULL=inherit court peak_members_only, 0=open during peak, 1=members-only during peak';

ALTER TABLE blocked_slots
    ADD COLUMN block_kind VARCHAR(32) NOT NULL DEFAULT 'other';

ALTER TABLE blocked_slots
    ADD COLUMN repeat_annually TINYINT(1) NOT NULL DEFAULT 0;
