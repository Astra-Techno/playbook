-- Additive. A tournament entry payment is distinct from a booking or a membership.
ALTER TABLE payments
    MODIFY type ENUM('booking','subscription','tournament') NOT NULL DEFAULT 'booking';
