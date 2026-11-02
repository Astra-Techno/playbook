-- Additive. Arrival on a booking. Status values are unchanged.
ALTER TABLE bookings
    ADD COLUMN attendance VARCHAR(20) NULL DEFAULT NULL;
