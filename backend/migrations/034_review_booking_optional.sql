-- A venue review does not have to point at a booking.
ALTER TABLE reviews MODIFY booking_id INT NULL;
