-- Additive. Records how a walk-in price is taken.
-- Online bookings leave this null. payment_status is unchanged.
ALTER TABLE bookings
    ADD COLUMN collection_method VARCHAR(32) NULL DEFAULT NULL;
